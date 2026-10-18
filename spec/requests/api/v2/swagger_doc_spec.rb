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

  it 'documents json/xml output via the format query param on the endpoints that support xml' do
    get '/api/v2/swagger_doc'

    paths = JSON.parse(response.body)['paths']
    format_param = ->(path) { paths[path]['get']['parameters'].to_a.find { |p| p['name'] == 'format' } }

    xml_paths = ['/api/v2/stats/gold', '/api/v2/stats/prices/{id}', '/api/v2/stats/orderbook/{id}',
                 '/api/v2/stats/history/{id}', '/api/v2/stats/charts/{id}']
    xml_paths.each do |path|
      expect(paths[path]['get']['produces']).to eq(['application/json', 'application/xml'])
      expect(format_param.call(path)).to include('in' => 'query', 'enum' => %w[json xml], 'default' => 'json')
    end

    (paths.keys - xml_paths).each do |path|
      expect(paths[path]['get']['produces']).to eq(['application/json'])
      expect(format_param.call(path)).to be_nil
    end
  end
end
