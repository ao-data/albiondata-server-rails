require 'rails_helper'

RSpec.describe 'GET /api/v2/swagger_doc', type: :request do
  it 'returns 200 with all eight stats endpoints documented' do
    get '/api/v2/swagger_doc'

    expect(response).to have_http_status(:success)
    doc = JSON.parse(response.body)
    expect(doc['paths'].keys).to match_array([
      '/api/v2/stats/gold',
      '/api/v2/stats/prices/{id}',
      '/api/v2/stats/view/{id}',
      '/api/v2/stats/history/{id}',
      '/api/v2/stats/charts/{id}',
      '/api/v2/stats/orderbook/{id}',
      '/api/v2/stats/festivities',
      '/api/v2/stats/identifier/{identifier}',
    ])
  end
end
