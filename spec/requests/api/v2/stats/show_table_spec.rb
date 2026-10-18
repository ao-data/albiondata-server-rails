require 'rails_helper'

RSpec.describe 'GET /api/v2/stats/view/:id', type: :request do
  let(:market_data_service) { instance_double(MarketDataService) }
  let(:sorted_results) do
    [
      { item_id: 'T4_BAG', city: 'Thetford', quality: 1, sell_price_min: 100, sell_price_min_date: '2022-01-01T00:00:00',
        sell_price_max: 200, sell_price_max_date: '2022-01-02T00:00:00', buy_price_min: 0, buy_price_min_date: DateTime.new(1, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S'),
        buy_price_max: 150, buy_price_max_date: '2022-01-04T00:00:00' }
    ]
  end

  before do
    allow(MarketDataService).to receive(:new).and_return(market_data_service)
    allow(market_data_service).to receive(:get_stats).and_return(sorted_results)
  end

  it 'renders an HTML table with a row per result' do
    get '/api/v2/stats/view/T4_BAG'

    expect(response).to have_http_status(:success)
    expect(response.content_type).to eq('text/html; charset=utf-8')
    expect(response.body).to include('<table')
    expect(response.body).to include('<th>item_id</th>')
    expect(response.body).to include('<td>T4_BAG</td>')
    expect(response.body).to include('<td>Thetford</td>')
    expect(response.body).to include('<td>100</td>')
    expect(response.body).to include('<td>200</td>')
  end

  it 'renders zero and default-date values as empty cells' do
    get '/api/v2/stats/view/T4_BAG'

    expect(response).to have_http_status(:success)
    expect(response.body).to include('<td></td>')
  end

  it 'renders an empty table body when there are no results' do
    allow(market_data_service).to receive(:get_stats).and_return([])

    get '/api/v2/stats/view/T4_BAG'

    expect(response).to have_http_status(:success)
    expect(response.body).to include('<table')
    expect(response.body).not_to include('<td>')
  end

  context 'when locations is passed as an array-style query param' do
    it 'renders an HTML table with a row per result' do
      get '/api/v2/stats/view/T4_BAG', params: { locations: ['Caerleon', 'Martlock'] }

      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
      expect(response.body).to include('<table')
      expect(response.body).to include('<td>T4_BAG</td>')
    end
  end
end
