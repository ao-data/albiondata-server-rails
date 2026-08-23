require 'rails_helper'

RSpec.describe API::V2::Stats::FestivitiesController, type: :controller do
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
    @request.host = 'west.example.com'
    redis.del(FestivitiesService::CURRENT_SNAPSHOT_KEY)
  end

  after do
    redis.del(FestivitiesService::CURRENT_SNAPSHOT_KEY)
  end

  it 'returns the latest confirmed regional snapshot' do
    redis.set(FestivitiesService::CURRENT_SNAPSHOT_KEY, snapshot.to_json)

    get :index

    expect(response).to be_successful
    expect(JSON.parse(response.body)).to eq(snapshot)
    expect(response.headers['Cache-Control'].split(', ')).to contain_exactly(
      'public',
      'max-age=60',
      'stale-while-revalidate=300'
    )
  end

  it 'returns not found when no snapshot has been confirmed' do
    get :index

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq('error' => 'No confirmed festivities snapshot')
  end
end
