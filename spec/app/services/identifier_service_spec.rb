describe IdentifierService, type: :service do

  describe '.add_identifier_event' do
    let(:opts) { { identifier: 'test_identifier' } }
    let(:server) { 'test_server' }
    let(:event) { 'test_event' }
    let(:natsmsg) { nil }
    let(:expiration) { 600 }

    before do
      key = "IDENTIFIER:#{opts[:identifier]}"
      REDIS['identifier'].del(key)
    end

    it 'adds an event to the identifier' do
      described_class.add_identifier_event(opts, server, event, natsmsg, expiration)

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
