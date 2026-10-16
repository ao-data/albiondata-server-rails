require 'rails_helper'

RSpec.describe GameinfoService, type: :service do
  subject { described_class.new(server_id) }

  let(:server_id) { 'west' }
  let(:redis) { REDIS[server_id] }
  let(:nats) { instance_double(NatsService, send: nil, close: nil) }
  let(:base_url) { 'https://gameinfo.albiononline.com/api/gameinfo' }
  let(:pages) { {} }

  before do
    clear_gameinfo_keys
    allow(Sidekiq.logger).to receive(:info)
    allow(NatsService).to receive(:new).with(server_id).and_return(nats)
    allow(subject).to receive(:sleep)
    allow(HTTParty).to receive(:get) do |url, **_options|
      body = pages.fetch(url, [])
      case body
      when :not_found then response(404, '')
      when :error then response(500, '')
      when :bad_request then response(400, '')
      else response(200, body.to_json)
      end
    end
  end

  after do
    clear_gameinfo_keys
  end

  describe '#poll_events' do
    it 'publishes new events and stops at the first page without new events' do
      pages[events_url(0)] = [event(3), event(2)]
      pages[events_url(51)] = [event(1)]
      subject.poll_events

      expect(nats).to have_received(:send).with('killevents.deduped', event(3).to_json)
      expect(nats).to have_received(:send).with('killevents.deduped', event(2).to_json)
      expect(nats).to have_received(:send).with('killevents.deduped', event(1).to_json)

      pages[events_url(0)] = [event(4), event(3)]
      subject.poll_events

      expect(nats).to have_received(:send).exactly(4).times
      expect(HTTParty).to have_received(:get).with(events_url(51), anything).twice
      expect(HTTParty).to have_received(:get).with(events_url(102), anything).once
    end

    it 'stops at the max offset' do
      event_ids = Queue.new
      (1..100).each { |id| event_ids << id }
      allow(HTTParty).to receive(:get) { response(200, [event(event_ids.pop)].to_json) }

      subject.poll_events

      expect(HTTParty).to have_received(:get).exactly(20).times
      expect(HTTParty).to have_received(:get).with(events_url(969), anything)
      expect(Sidekiq.logger).to have_received(:info).with(/"missed_older":true/)
    end

    it 'fetches the next pages in parallel once a page has only new events' do
      in_flight = 0
      max_in_flight = 0
      lock = Mutex.new
      allow(HTTParty).to receive(:get) do |url, **_options|
        lock.synchronize { max_in_flight = [max_in_flight, in_flight += 1].max }
        Kernel.sleep(0.2)
        lock.synchronize { in_flight -= 1 }
        response(200, pages.fetch(url, []).to_json)
      end
      pages[events_url(0)] = [event(6), event(5)]
      pages[events_url(51)] = [event(4), event(3)]
      pages[events_url(102)] = [event(2), event(1)]
      subject.poll_events

      expect(max_in_flight).to eq(4)
      [0, 51, 102, 153, 204].each { |offset| expect(HTTParty).to have_received(:get).with(events_url(offset), anything).once }
      expect(nats).to have_received(:send).exactly(6).times
    end

    it 'leaves no resume point after runs that catch up' do
      pages[events_url(0)] = [event(2), event(1)]
      subject.poll_events

      expect(redis.exists?(GameinfoService::EVENTS_RESUME_KEY)).to be(false)

      pages[events_url(0)] = [event(3), event(2)]
      subject.poll_events

      expect(redis.exists?(GameinfoService::EVENTS_RESUME_KEY)).to be(false)
    end

    describe 'after a run that stopped early' do
      it 'keeps reading past the published pages until it gets below the oldest event reached' do
        # One event per page, newest first. Page 255 fails in the first run (a 400, which starts no cooldown).
        { 0 => 10, 51 => 9, 102 => 8, 153 => 7, 204 => 6, 306 => 4 }.each { |offset, id| pages[events_url(offset)] = [event(id)] }
        pages[events_url(255)] = :bad_request
        subject.poll_events

        expect(redis.get(GameinfoService::EVENTS_RESUME_KEY)).to eq('4')
        expect(nats).not_to have_received(:send).with('killevents.deduped', event(5).to_json)

        # The next run finds the first pages already published but keeps going down to the gap.
        pages[events_url(255)] = [event(5)]
        subject.poll_events

        expect(nats).to have_received(:send).with('killevents.deduped', event(5).to_json)
        expect(redis.get(GameinfoService::EVENTS_RESUME_KEY)).to be_nil
      end

      it 'stops at a page without new events once it is below the resume point' do
        pages[events_url(0)] = [event(6), event(5)]
        pages[events_url(51)] = [event(4), event(3)]
        pages[events_url(102)] = [event(2), event(1)]
        pages[events_url(153)] = [event(0)]
        subject.poll_events
        redis.set(GameinfoService::EVENTS_RESUME_KEY, 3)

        subject.poll_events

        expect(redis.get(GameinfoService::EVENTS_RESUME_KEY)).to be_nil
        expect(HTTParty).to have_received(:get).with(events_url(102), anything).twice
      end

      it 'keeps the resume point when the run reads nothing' do
        redis.set(GameinfoService::EVENTS_RESUME_KEY, 3)
        pages[events_url(0)] = :error
        subject.poll_events

        expect(redis.get(GameinfoService::EVENTS_RESUME_KEY)).to eq('3')
      end
    end

    it 'tracks the battle of each new event by when it was seen' do
      # The fixture events are more than an hour old, like events first seen during a catch-up.
      pages[events_url(0)] = [event(2, battle_id: 1), event(1, battle_id: 1)]
      subject.poll_events
      subject.poll_events

      # Only newly published events count, so the second run adds no kills.
      expect(redis.get('gameinfo:battle:1:kills')).to eq('2')
      expect(redis.ttl('gameinfo:battle:1:kills')).to be_between(1, GameinfoService::BACKFILL_GIVE_UP_SECONDS)
      expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_within(5).of(Time.now.to_i)
    end

    it 'drops battles past the give up time when tracking, even if the battles job does not run' do
      track_battle(9, kills: 3, last_seen_at: 2.hours.ago)
      pages[events_url(0)] = [event(1)]
      subject.poll_events

      expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '9')).to be_nil
      expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_present
    end

    it 'publishes events with a missing or malformed TimeStamp' do
      pages[events_url(0)] = [event(2).merge('TimeStamp' => 'not a time'), event(1).merge('TimeStamp' => nil)]
      allow(ActiveSupport::Notifications).to receive(:instrument)
      subject.poll_events

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'metrics.gameinfo_service', hash_including(server_id: 'west', job: 'events', published: 2, timed_out: 0)
      )
      expect(ActiveSupport::Notifications).not_to have_received(:instrument).with(
        'metrics.gameinfo_service', hash_including(:lag_seconds)
      )
    end

    it 'skips the run and sends a metric when a previous run holds the lock' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      redis.set('gameinfo:lock:events', 'other')
      subject.poll_events

      expect(HTTParty).not_to have_received(:get)
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'metrics.gameinfo_service', { server_id: 'west', job: 'events', skipped: 1 }
      )
    end

    it 'releases the lock after a successful run' do
      subject.poll_events

      expect(redis.get('gameinfo:lock:events')).to be_nil
    end

    it 'does not release a lock taken by another run' do
      allow(HTTParty).to receive(:get) do
        redis.set('gameinfo:lock:events', 'other')
        response(200, [].to_json)
      end
      subject.poll_events

      expect(redis.get('gameinfo:lock:events')).to eq('other')
    end

    it 'keeps the lock and forgets the event when publishing fails' do
      pages[events_url(0)] = [event(1)]
      allow(nats).to receive(:send).and_raise('nats down')

      expect { subject.poll_events }.to raise_error('nats down')
      expect(redis.get('gameinfo:lock:events')).to be_present
      expect(redis.exists?('gameinfo:killevent:1')).to be(false)
      expect(nats).to have_received(:close)
    end

    it 'forgets only the events that were not sent when publishing fails partway' do
      pages[events_url(0)] = [event(2), event(1)]
      allow(nats).to receive(:send).with('killevents.deduped', event(1).to_json).and_raise('nats down')

      expect { subject.poll_events }.to raise_error('nats down')
      expect(redis.exists?('gameinfo:killevent:2')).to be(true)
      expect(redis.exists?('gameinfo:killevent:1')).to be(false)
    end

    it 'forgets the event when Sidekiq kills the job while publishing' do
      pages[events_url(0)] = [event(1)]
      allow(nats).to receive(:send).and_raise(Sidekiq::Shutdown)

      expect { subject.poll_events }.to raise_error(Sidekiq::Shutdown)
      expect(redis.exists?('gameinfo:killevent:1')).to be(false)
    end

    it 'sends run metrics' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      pages[events_url(0)] = [event(2), event(1)]
      subject.poll_events

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'metrics.gameinfo_service',
        hash_including(server_id: 'west', job: 'events', published: 2, timed_out: 0, lag_seconds: kind_of(Integer))
      )
    end

    it 'adds a different cache breaker to every request' do
      pages[events_url(0)] = [event(1)]
      subject.poll_events

      cache_breakers = []
      expect(HTTParty).to have_received(:get).exactly(3).times do |_url, **options|
        cache_breakers << options.dig(:query, :_)
      end
      expect(cache_breakers).to all(match(/\A\h{16}\z/))
      expect(cache_breakers.uniq.size).to eq(3)
    end

    describe 'rate limits and failures' do
      let(:cooldown_key) { 'gameinfo:cooldown:events' }

      it 'cools down the endpoint on a 429 without retrying, and skips requests until it ends' do
        allow(HTTParty).to receive(:get).and_return(response(429, ''))
        subject.poll_events
        subject.poll_events

        expect(HTTParty).to have_received(:get).once
        expect(redis.pttl(cooldown_key)).to be_between(4_000, 5_500)
      end

      it 'honours Retry-After' do
        allow(HTTParty).to receive(:get).and_return(response(429, '', 'retry-after' => '120'))
        subject.poll_events

        expect(redis.pttl(cooldown_key)).to be_between(119_000, 120_500)
      end

      it 'treats a Cloudflare 1015 page as a rate limit' do
        allow(HTTParty).to receive(:get).and_return(response(403, 'error code: 1015'))
        subject.poll_events

        expect(HTTParty).to have_received(:get).once
        expect(redis.exists?(cooldown_key)).to be(true)
      end

      it 'retries server errors with a backoff, then cools down the endpoint' do
        pages[events_url(0)] = :error
        subject.poll_events

        expect(HTTParty).to have_received(:get).exactly(3).times
        expect(subject).to have_received(:sleep).with(a_value_between(2, 2.5))
        expect(subject).to have_received(:sleep).with(a_value_between(4, 4.5))
        expect(redis.pttl(cooldown_key)).to be_between(29_000, 30_500)
      end

      it 'doubles the cooldown for consecutive failures and resets it after a success' do
        pages[events_url(0)] = :error
        subject.poll_events
        redis.del(cooldown_key)
        subject.poll_events

        expect(redis.pttl(cooldown_key)).to be_between(59_000, 60_500)

        redis.del(cooldown_key)
        pages[events_url(0)] = [event(1)]
        subject.poll_events

        expect(redis.exists?("#{cooldown_key}:level")).to be(false)
      end

      it 'does not cool down on other client errors' do
        pages[events_url(0)] = :bad_request
        subject.poll_events

        expect(HTTParty).to have_received(:get).once
        expect(redis.exists?(cooldown_key)).to be(false)
      end

      it 'cools down events and battles separately' do
        redis.set(cooldown_key, '1', ex: 60)
        pages[battles_url(0)] = [battle(1)]
        subject.poll_battles

        expect(nats).to have_received(:send).with('battles.deduped', battle(1).to_json)
      end

      it 'sends a cooldown metric' do
        allow(ActiveSupport::Notifications).to receive(:instrument)
        allow(HTTParty).to receive(:get).and_return(response(429, ''))
        subject.poll_events

        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          'metrics.gameinfo_service', { server_id: 'west', job: 'events', cooldown_seconds: 5 }
        )
      end
    end
  end

  describe '#poll_battles' do
    it 'publishes each listed battle once and stops at the first page without new battles' do
      pages[battles_url(0)] = [battle(2), battle(1)]
      pages[battles_url(51)] = [battle(1)]
      subject.poll_battles
      subject.poll_battles

      expect(nats).to have_received(:send).with('battles.deduped', battle(2).to_json).once
      expect(nats).to have_received(:send).with('battles.deduped', battle(1).to_json).once
      expect(HTTParty).to have_received(:get).with(battles_url(0), anything).twice
      expect(HTTParty).to have_received(:get).with(battles_url(51), anything).once
      expect(HTTParty).not_to have_received(:get).with(battles_url(102), anything)
    end

    it 'sends run metrics' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      pages[battles_url(0)] = [battle(1)]
      subject.poll_battles

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'metrics.gameinfo_service',
        { server_id: 'west', job: 'battles', published: 1, backfilled: 0, timed_out: 0, lag_seconds: kind_of(Integer) }
      )
    end

    it 'sends run metrics without the lag when endTime is malformed' do
      allow(ActiveSupport::Notifications).to receive(:instrument)
      pages[battles_url(0)] = [battle(1).merge('endTime' => 'not a time')]
      subject.poll_battles

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'metrics.gameinfo_service', { server_id: 'west', job: 'battles', published: 1, backfilled: 0, timed_out: 0 }
      )
    end

    describe 'backfill' do
      let(:battle_url) { "#{base_url}/battles/1" }

      it 'publishes a tracked battle the list never showed' do
        track_battle(1, kills: 3, last_seen_at: 20.minutes.ago)
        pages[battle_url] = battle(1)
        subject.poll_battles

        expect(nats).to have_received(:send).with('battles.deduped', battle(1).to_json)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_nil
      end

      it 'waits for recent battles' do
        track_battle(1, kills: 3, last_seen_at: 5.minutes.ago)
        subject.poll_battles

        expect(HTTParty).not_to have_received(:get).with(battle_url, anything)
      end

      it 'drops battles with fewer than 3 kills without fetching them' do
        track_battle(1, kills: 2, last_seen_at: 20.minutes.ago)
        subject.poll_battles

        expect(HTTParty).not_to have_received(:get).with(battle_url, anything)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_nil
      end

      it 'keeps retrying a battle that is not found yet' do
        track_battle(1, kills: 3, last_seen_at: 20.minutes.ago)
        pages[battle_url] = :not_found
        subject.poll_battles

        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_present
      end

      it 'gives up on a battle after an hour' do
        track_battle(1, kills: 3, last_seen_at: 2.hours.ago)
        pages[battle_url] = :not_found
        subject.poll_battles

        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_nil
        expect(redis.exists?('gameinfo:battle:1:kills')).to be(false)
      end

      it 'stops while the battles endpoint is cooling down' do
        track_battle(1, kills: 3, last_seen_at: 20.minutes.ago)
        redis.set('gameinfo:cooldown:battles', '1', ex: 60)
        subject.poll_battles

        expect(HTTParty).not_to have_received(:get)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_present
      end

      it 'drops battles that were already published without fetching them' do
        track_battle(1, kills: 3, last_seen_at: 20.minutes.ago)
        redis.set('gameinfo:battle:1', '1')
        subject.poll_battles

        expect(HTTParty).not_to have_received(:get).with(battle_url, anything)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '1')).to be_nil
        expect(redis.exists?('gameinfo:battle:1:kills')).to be(false)
      end

      it 'handles at most BACKFILL_BATCH_SIZE battles per run, oldest first' do
        stub_const('GameinfoService::BACKFILL_BATCH_SIZE', 2)
        track_battle(1, kills: 3, last_seen_at: 30.minutes.ago)
        track_battle(2, kills: 1, last_seen_at: 25.minutes.ago)
        track_battle(3, kills: 3, last_seen_at: 20.minutes.ago)
        pages[battle_url] = battle(1)
        subject.poll_battles

        expect(nats).to have_received(:send).with('battles.deduped', battle(1).to_json)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '2')).to be_nil
        expect(HTTParty).not_to have_received(:get).with("#{base_url}/battles/3", anything)
        expect(redis.zscore(GameinfoService::PENDING_BATTLES_KEY, '3')).to be_present
      end
    end
  end

  def events_url(offset)
    "#{base_url}/events?limit=51&offset=#{offset}"
  end

  def battles_url(offset)
    "#{base_url}/battles?sort=recent&limit=51&offset=#{offset}"
  end

  def event(id, battle_id: id)
    { 'EventId' => id, 'BattleId' => battle_id, 'TimeStamp' => '2026-10-15T15:20:05.7291611Z' }
  end

  def battle(id)
    { 'id' => id, 'totalKills' => 3, 'endTime' => '2026-10-15T15:20:05.535053800Z' }
  end

  def track_battle(battle_id, kills:, last_seen_at:)
    redis.zadd(GameinfoService::PENDING_BATTLES_KEY, last_seen_at.to_i, battle_id)
    redis.set("gameinfo:battle:#{battle_id}:kills", kills)
  end

  def response(code, body, headers = {})
    double('HTTParty::Response', success?: code == 200, code: code, body: body, headers: headers)
  end

  def clear_gameinfo_keys
    keys = redis.keys('gameinfo:*')
    redis.del(*keys) if keys.any?
  end
end
