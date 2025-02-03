describe IdentifierService, type: :service do
  describe '.add_identifier_event' do
    let(:opts) { { identifier: 'test_identifier' } }
    let(:server) { 'test_server' }
    let(:event) { 'test_event' }
    let(:natsmsg) { nil }

    before do
      key = "IDENTIFIER:#{opts[:identifier]}"
      REDIS['identifier'].del(key)
    end

    it 'adds an event to the identifier' do
      described_class.add_identifier_event(opts, server, event, natsmsg)

      key = "IDENTIFIER:#{server}:#{opts[:identifier]}"
      response = REDIS['identifier'].lrange(key, 0, -1)
      parsed_response = response.map { |json_str| JSON.parse(json_str) }

      added_event = parsed_response.find { |e| e['event'] == event }

      expect(added_event).to include(
        'server' => server,
        'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'),
        'natsmsg' => nil,
        'event' => event
      )
    end

    describe 'when there is no IDENTIFIER_EXPIRATION env var set' do
      it 'sets an expiration time for the key' do
        described_class.add_identifier_event(opts, server, event, natsmsg)

        key = "IDENTIFIER:#{server}:#{opts[:identifier]}"
        expiration = REDIS['identifier'].ttl(key)

        expect(expiration).to eq 86400
      end
    end

    describe 'when there is an IDENTIFIER_EXPIRATION env var set' do
      before do
        allow(ENV).to receive(:fetch).with('IDENTIFIER_EXPIRATION', 600).and_return(300)
      end

      it 'sets an expiration time for the key' do
        described_class.add_identifier_event(opts, server, event, natsmsg)

        key = "IDENTIFIER:#{server}:#{opts[:identifier]}"
        expiration = REDIS['identifier'].ttl(key)

        expect(expiration).to eq 300
      end
    end
  end

  describe '.get_identifier_events' do
    let(:identifier) { 'test_identifier' }
    let(:server) { 'test_server' }

    before do
      key = "IDENTIFIER:#{server}:#{identifier}"
      REDIS['identifier'].del(key)
    end

    after do
      key = "IDENTIFIER:#{server}:#{identifier}"
      REDIS['identifier'].del(key)
    end

    it 'returns the events associated with the identifier' do
      key = "IDENTIFIER:#{server}:#{identifier}"
      REDIS['identifier'].rpush(key, { server: server, timestamp: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'), natsmsg: nil, event: 'test_event' }.to_json)

      response = described_class.get_identifier_events(identifier, server)

      expect(response).to eq([
        { 'server' => server, 'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'), 'natsmsg' => nil, 'event' => 'test_event' }
      ])
    end
  end
end
