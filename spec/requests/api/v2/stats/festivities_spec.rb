require 'rails_helper'

RSpec.describe 'GET /api/v2/stats/festivities', type: :request do
  let(:redis) { REDIS['west'] }
  let(:snapshot) do
    {
      'Server' => 'west',
      'ConfirmedAt' => '2026-08-02T12:00:00Z',
      'ExpiresAt' => '2026-08-03T10:00:00Z',
      'Events' => [
        {
          'Kind' => 2,
          'Category' => 'GENERAL',
          'UniqueName' => 'COMMON_BOW',
          'StartTime' => 639211752000000000,
          'EndTime' => 639212616000000000
        }
      ]
    }
  end

  before do
    host! 'west.example.com'
    redis.del(FestivitiesService::CURRENT_SNAPSHOT_KEY)
  end

  after do
    redis.del(FestivitiesService::CURRENT_SNAPSHOT_KEY)
  end

  it 'returns the latest confirmed regional snapshot' do
    redis.set(FestivitiesService::CURRENT_SNAPSHOT_KEY, snapshot.to_json)

    get '/api/v2/stats/festivities'

    expect(response).to be_successful
    expect(JSON.parse(response.body)).to eq(snapshot)
    expect(response.headers['Cache-Control'].split(', ')).to contain_exactly(
      'public',
      'max-age=60',
      'stale-while-revalidate=300'
    )
  end

  it 'returns not found when no snapshot has been confirmed' do
    get '/api/v2/stats/festivities'

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq('error' => 'No confirmed festivities snapshot')
  end

  it 'returns valid JSON, not a mangled body, when .xml format is requested' do
    redis.set(FestivitiesService::CURRENT_SNAPSHOT_KEY, snapshot.to_json)

    get '/api/v2/stats/festivities.xml'

    expect(response).to be_successful
    expect { JSON.parse(response.body) }.not_to raise_error
    expect(JSON.parse(response.body)).to eq(snapshot)
  end
end
