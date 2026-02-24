describe BanditEventService, type: :service do

  describe '.process' do
    let(:server_id) { 'west' }
    let(:now) { Time.utc(2026, 2, 2, 12, 0, 0) }
    let(:event_time_ticks) { BanditEventService::CSHARP_TICKS_UNIX_EPOCH + (now.to_i * BanditEventService::CSHARP_TICKS_PER_SECOND) }
    let(:data) { { 'EventTime' => event_time_ticks, 'Phase' => 1 } }
    let(:opts) { { 'client_ip' => '1.2.3.4', 'identifier' => 'abc' } }
    let(:redis) { instance_double(Redis) }

    before do
      allow(Time).to receive(:now).and_return(now)
      allow(REDIS).to receive(:[]).with(server_id).and_return(redis)
      allow(redis).to receive(:sadd)
      allow(redis).to receive(:expire)
      allow(redis).to receive(:scard).and_return(0)
      allow(IdentifierService).to receive(:add_identifier_event)
    end

    it 'sends a log message' do
      expected_log =  { class: 'BanditEventService', method: 'process', data: data, server_id: server_id, opts: opts }.to_json
      expect(Sidekiq.logger).to receive(:info).with(expected_log)
      subject.process(data, server_id, opts)
    end

    it 'sends to NATS when distinct ips exceed threshold' do
      allow(redis).to receive(:scard).and_return(6)
      nats = instance_double(NatsService)

      expect(NatsService).to receive(:new).with(server_id).and_return(nats)
      expect(nats).to receive(:send).with('banditevent.ingest', data.to_json)
      expect(nats).to receive(:close)
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /sent to NATS/)

      subject.process(data, server_id, opts)
    end

    it 'does not send to NATS when distinct ips are below threshold' do
      allow(redis).to receive(:scard).and_return(5)

      expect(NatsService).not_to receive(:new)
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /below threshold/)

      subject.process(data, server_id, opts)
    end

    it 'accepts int Phase values' do
      data_with_false = { 'EventTime' => event_time_ticks, 'Phase' => 1 }

      expect(redis).to receive(:sadd).with("event:#{event_time_ticks}:false:ips", opts['client_ip'])
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /below threshold/)

      subject.process(data_with_false, server_id, opts)
    end

    it 'ignores events with invalid EventTime ticks' do
      bad_data = { 'EventTime' => 'not-a-tick', 'Phase' => 1 }

      expect(REDIS).not_to receive(:[])
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /invalid EventTime/)

      subject.process(bad_data, server_id, opts)
    end

    it 'ignores events with EventTime in the past' do
      now = Time.utc(2026, 2, 2, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now)
      past_ticks = BanditEventService::CSHARP_TICKS_UNIX_EPOCH + ((now.to_i - 1) * BanditEventService::CSHARP_TICKS_PER_SECOND)
      past_data = { 'EventTime' => past_ticks, 'Phase' => 1 }

      expect(REDIS).not_to receive(:[])
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /EventTime out of allowed window/)

      subject.process(past_data, server_id, opts)
    end

    it 'ignores events with EventTime more than 5 hours ahead' do
      now = Time.utc(2026, 2, 2, 12, 0, 0)
      allow(Time).to receive(:now).and_return(now)
      future_seconds = (now + 6.hours).to_i
      future_ticks = BanditEventService::CSHARP_TICKS_UNIX_EPOCH + (future_seconds * BanditEventService::CSHARP_TICKS_PER_SECOND)
      future_data = { 'EventTime' => future_ticks, 'Phase' => 1 }

      expect(REDIS).not_to receive(:[])
      expect(IdentifierService).to receive(:add_identifier_event).with(opts, server_id, /EventTime out of allowed window/)

      subject.process(future_data, server_id, opts)
    end
  end
end
