require 'rails_helper'

RSpec.describe 'GET /api/v2/stats/gold', type: :request do
  let(:gold_price) { create(:gold_price) }

  before do
    GoldPrice.destroy_all
    gold_price
  end

  context 'when date and end_date parameters are not provided' do
    it 'returns gold prices for the last month' do
      get '/api/v2/stats/gold'

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([
        { 'price' => gold_price.price / 10000, 'timestamp' => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
      ])
    end
  end

  context 'when date and end_date parameters are provided' do
    let(:date) { Date.today - 1.month }
    let(:end_date) { Date.today }

    it 'returns gold prices for the specified date range' do
      get '/api/v2/stats/gold', params: { date: date.strftime('%m-%d-%Y'), end_date: end_date.strftime('%m-%d-%Y') }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([
        { 'price' => gold_price.price / 10000, 'timestamp' => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
      ])
    end
  end

  context 'when date is provided but end_date is not' do
    let(:date) { Date.today - 1.month }

    it 'returns gold prices from the specified date to one month later' do
      get '/api/v2/stats/gold', params: { date: date.strftime('%m-%d-%Y') }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([
        { 'price' => gold_price.price / 10000, 'timestamp' => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
      ])
    end
  end

  context 'when end_date is provided but date is not' do
    let(:end_date) { Date.today }

    it 'returns gold prices from one month before the specified end_date to the end_date' do
      get '/api/v2/stats/gold', params: { end_date: end_date.strftime('%m-%d-%Y') }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([
        { 'price' => gold_price.price / 10000, 'timestamp' => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
      ])
    end
  end

  context 'when there is gold data older than a month' do
    it 'does not return gold prices older than a month' do
      create(:gold_price, timestamp: 2.months.ago)

      get '/api/v2/stats/gold'

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([
        { 'price' => gold_price.price / 10000, 'timestamp' => gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S') }
      ])
    end
  end

  context 'when the request wants xml' do
    it 'returns the gold prices in xml format' do
      get '/api/v2/stats/gold.xml'

      expect(response).to have_http_status(:success)
      expect(response.body).to eq("<?xml version=\"1.0\"?>\n<ArrayOfGoldPrice xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n  <GoldPrice>\n    <Id>#{gold_price.id}</Id>\n    <Price>#{gold_price.price / 10000}</Price>\n    <Timestamp>#{gold_price.timestamp.strftime('%Y-%m-%dT%H:%M:%S')}</Timestamp>\n  </GoldPrice>\n</ArrayOfGoldPrice>\n")
    end
  end

  it 'returns the gold prices in asc order when there is no count specified' do
    create(:gold_price, timestamp: 2.days.ago)

    get '/api/v2/stats/gold'

    first_record_timestamp = JSON.parse(response.body).first['timestamp']
    second_record_timestamp = JSON.parse(response.body).second['timestamp']
    expect(first_record_timestamp).to be < second_record_timestamp
  end

  it 'returns the gold prices in desc order when there is a count specified' do
    create(:gold_price, timestamp: 2.days.ago)

    get '/api/v2/stats/gold', params: { count: '2' }

    first_record_timestamp = JSON.parse(response.body).first['timestamp']
    second_record_timestamp = JSON.parse(response.body).second['timestamp']
    expect(first_record_timestamp).to be > second_record_timestamp
  end

  it 'returns only 1 if count 1 is specified' do
    create(:gold_price, timestamp: 2.days.ago)

    get '/api/v2/stats/gold', params: { count: '1' }

    expect(JSON.parse(response.body).count).to eq(1)
  end

  it 'returns a Content-Type header with an explicit charset' do
    get '/api/v2/stats/gold'

    expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
  end

  context 'when an unsupported HTTP method is used' do
    it 'returns 405 Method Not Allowed instead of 500' do
      post '/api/v2/stats/gold'

      expect(response).to have_http_status(:method_not_allowed)
    end
  end
end
