require 'rails_helper'

RSpec.describe Ipdb, :type => :class do
  let(:ipdb) { Ipdb.new }
  let(:ip) { '1.1.1.1' }

  describe '#check_ip' do
    before do
      allow(ABUSEIPDB_REDIS).to receive(:sismember).with('bad_ips', ip).and_return(false)
      allow(ABUSEIPDB_REDIS).to receive(:get).with('checked_ip_1.1.1.1').and_return(false)
      allow(ABUSEIPDB_REDIS).to receive(:get).with('apidb-rate-limit-remaining').and_return(9999)
      allow(ABUSEIPDB_REDIS).to receive(:set).with('checked_ip_1.1.1.1', 1, ex: 604800)
      allow(ABUSEIPDB_REDIS).to receive(:set).with('apidb-rate-limit-remaining', 100, ex: 1800)
      ENV['ABUSEIPDB_SCORE_THRESHOLD'] = '10'
    end

    it 'returns false if the ip is in the bad list' do
      allow(ABUSEIPDB_REDIS).to receive(:sismember).with('bad_ips', ip).and_return(true)
      expect(ipdb.check_ip(ip)).to eq(false)
    end

    it 'returns true if the ip was checked and came back clean' do
      allow(ABUSEIPDB_REDIS).to receive(:get).with('checked_ip_1.1.1.1').and_return(true)
      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns true if we dont have an api key' do
      allow(ipdb).to receive(:api_key).and_return(nil)
      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns true if we are close to rate limit' do
      allow(ABUSEIPDB_REDIS).to receive(:get).and_return(100)
      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns true if there was an error' do
      allow(Abuseipdb).to receive_message_chain(:client, :check, :call).and_raise(StandardError)
      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns false if the score is greater than 10' do
      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 11 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ipdb.check_ip(ip)).to eq(false)
    end

    it 'returns true if the score is less than or equal to 10' do
      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 1 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns true if the score is less than or equal to ENV["ABUSEIPDB_SCORE_THRESHOLD"]' do
      ENV['ABUSEIPDB_SCORE_THRESHOLD'] = '100'

      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 100 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ipdb.check_ip(ip)).to eq(true)
    end

    it 'returns false if the score is greater than ENV["ABUSEIPDB_SCORE_THRESHOLD"]' do
      ENV['ABUSEIPDB_SCORE_THRESHOLD'] = '100'

      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 101 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ipdb.check_ip(ip)).to eq(false)
    end

    it 'stores the rate limit remaining' do
      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 1 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ABUSEIPDB_REDIS).to receive(:set).with('apidb-rate-limit-remaining', 100, ex: 1800)

      ipdb.check_ip(ip)
    end

    it 'adds the ip to the bad list if the score is greater than 10' do
      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 11 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ABUSEIPDB_REDIS).to receive(:sadd).with('bad_ips', ip)

      ipdb.check_ip(ip)
    end

    it 'does not add the ip to the bad list if the score is less than or equal to 10' do
      result = double
      allow(result).to receive(:body).and_return({ 'data' => { 'abuseConfidenceScore' => 1 } })
      allow(result).to receive_message_chain(:raw_response, :env, :response_headers).and_return({ 'x-ratelimit-remaining' => 100 })

      check = double
      allow(check).to receive(:call).with(ipAddress: ip).and_return(result)

      client = double
      allow(client).to receive(:check).and_return(check)
      allow(Abuseipdb).to receive(:client).and_return(client)

      expect(ABUSEIPDB_REDIS).not_to receive(:sadd)

      ipdb.check_ip(ip)
    end
  end
end