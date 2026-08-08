require 'rails_helper'

RSpec.describe FestivitiesService, type: :service do
  let(:server_id) { 'west' }
  let(:redis) { REDIS[server_id] }
  let(:now) { Time.utc(2026, 8, 2, 12, 0, 0) }
  let(:nats) { instance_double(NatsService, send: nil, close: nil) }
  let(:data) do
    {
      'Events' => [
        {
          'Kind' => 2,
          'Category' => 'GENERAL',
          'UniqueName' => 'COMMON_BOW',
          'StartTime' => ticks(now - 2.hours),
          'EndTime' => ticks(now + 22.hours)
        },
        {
          'Kind' => 1,
          'Category' => 'GATHERING',
          'UniqueName' => 'ORE',
          'StartTime' => ticks(now - 1.day),
          'EndTime' => ticks(now + 1.day)
        }
      ]
    }
  end

  before do
    clear_festivities_keys
    allow(Time).to receive(:now).and_return(now)
    allow(IdentifierService).to receive(:add_identifier_event)
    allow(Sidekiq.logger).to receive(:info)
    allow(NatsService).to receive(:new).with(server_id).and_return(nats)
    stub_const('FestivitiesService::MIN_DISTINCT_IPS', 2)
    stub_const('FestivitiesService::VOTE_TTL_SECONDS', 600)
  end

  after do
    clear_festivities_keys
  end

  it 'publishes and stores a canonical snapshot after the distinct-ip quorum' do
    subject.process(data, server_id, opts('1.1.1.1'))
    expect(NatsService).not_to have_received(:new)

    subject.process(data, server_id, opts('2.2.2.2'))

    expected_events = data['Events'].sort_by do |event|
      [event['Kind'], event['Category'], event['UniqueName'], event['StartTime'], event['EndTime']]
    end
    expect(nats).to have_received(:send).with(
      FestivitiesService::DEDUPED_TOPIC,
      { 'Events' => expected_events }.to_json
    )

    snapshot = JSON.parse(redis.get(FestivitiesService::CURRENT_SNAPSHOT_KEY))
    expect(snapshot).to include(
      'Server' => server_id,
      'ConfirmedAt' => now.iso8601,
      'ExpiresAt' => (now + 22.hours).iso8601,
      'Events' => expected_events
    )
    expect(redis.ttl(FestivitiesService::CURRENT_SNAPSHOT_KEY)).to be_between(22.hours.to_i - 1, 22.hours.to_i)
    expect(redis.ttl(FestivitiesService::CURRENT_DIGEST_KEY)).to be_between(22.hours.to_i - 1, 22.hours.to_i)
  end

  it 'does not count repeated submissions from one ip more than once' do
    subject.process(data, server_id, opts('1.1.1.1'))
    subject.process(data, server_id, opts('1.1.1.1'))

    expect(NatsService).not_to have_received(:new)
  end

  it 'moves an ip vote when that ip submits a different snapshot' do
    changed_data = Marshal.load(Marshal.dump(data))
    changed_data['Events'][0]['UniqueName'] = 'COMMON_CROSSBOW'

    subject.process(data, server_id, opts('1.1.1.1'))
    subject.process(changed_data, server_id, opts('1.1.1.1'))
    subject.process(data, server_id, opts('2.2.2.2'))

    expect(NatsService).not_to have_received(:new)
  end

  it 'does not publish the same confirmed snapshot twice' do
    subject.process(data, server_id, opts('1.1.1.1'))
    subject.process(data, server_id, opts('2.2.2.2'))
    expect(nats).to have_received(:send).once

    subject.process(data, server_id, opts('3.3.3.3'))
    expect(nats).to have_received(:send).once
  end

  it 'rejects an invalid event interval' do
    invalid_data = Marshal.load(Marshal.dump(data))
    invalid_data['Events'][0]['EndTime'] = invalid_data['Events'][0]['StartTime']

    subject.process(invalid_data, server_id, opts('1.1.1.1'))

    expect(NatsService).not_to have_received(:new)
    expect(redis.scan_each(match: 'festivities:candidate:*').to_a).to be_empty
  end

  it 'rejects a snapshot without an active event' do
    stale_data = Marshal.load(Marshal.dump(data))
    stale_data['Events'].each do |event|
      event['StartTime'] = ticks(now - 3.days)
      event['EndTime'] = ticks(now - 2.days)
    end

    subject.process(stale_data, server_id, opts('1.1.1.1'))

    expect(NatsService).not_to have_received(:new)
    expect(redis.scan_each(match: 'festivities:candidate:*').to_a).to be_empty
  end

  it 'rejects a snapshot containing an event that already ended' do
    stale_data = Marshal.load(Marshal.dump(data))
    stale_data['Events'][0]['StartTime'] = ticks(now - 1.hour)
    stale_data['Events'][0]['EndTime'] = ticks(now - 1.second)

    subject.process(stale_data, server_id, opts('1.1.1.1'))

    expect(NatsService).not_to have_received(:new)
    expect(redis.scan_each(match: 'festivities:candidate:*').to_a).to be_empty
  end

  it 'stores only a hash of the voter ip in candidate data' do
    subject.process(data, server_id, opts('1.1.1.1'))

    candidate_key = redis.scan_each(match: 'festivities:candidate:*').first
    voters = redis.zrange(candidate_key, 0, -1)
    expect(voters).to eq([Digest::SHA256.hexdigest('1.1.1.1')])
    expect(voters).not_to include('1.1.1.1')
  end

  it 'releases the publication lock when NATS fails' do
    allow(nats).to receive(:send).and_raise(StandardError, 'NATS unavailable')

    subject.process(data, server_id, opts('1.1.1.1'))
    expect do
      subject.process(data, server_id, opts('2.2.2.2'))
    end.to raise_error(StandardError, 'NATS unavailable')

    expect(redis.scan_each(match: 'festivities:publish:*').to_a).to be_empty
    expect(redis.get(FestivitiesService::CURRENT_SNAPSHOT_KEY)).to be_nil
  end

  def ticks(time)
    FestivitiesService::CSHARP_TICKS_UNIX_EPOCH + (time.to_i * FestivitiesService::CSHARP_TICKS_PER_SECOND)
  end

  def opts(client_ip)
    { 'client_ip' => client_ip, 'identifier' => "id-#{client_ip}" }
  end

  def clear_festivities_keys
    redis.scan_each(match: 'festivities:*').each do |key|
      redis.del(key)
    end
  end
end
