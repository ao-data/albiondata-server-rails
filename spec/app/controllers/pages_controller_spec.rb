# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PagesController, type: :controller do
  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'GET #faq' do
    it 'returns a success response' do
      get :faq
      expect(response).to be_successful
    end
  end

  describe 'GET #api' do
    it 'returns a success response' do
      get :api
      expect(response).to be_successful
    end
  end

  describe 'GET #client' do
    let(:stats_result) do
      GithubReleaseStatsService::Result.new(
        total_downloads: 100,
        latest_release_tag: 'v1.0.0',
        latest_release_downloads: 50,
        latest_downloads_by_os: { 'Windows' => 30, 'macOS' => 20 },
        latest_downloads_by_type: { 'Full install' => 50 },
        downloads_by_os: { 'Windows' => 60, 'macOS' => 40 },
        downloads_by_type: { 'Full install' => 100 },
        error: nil
      )
    end

    before do
      allow(GithubReleaseStatsService).to receive(:call).and_return(stats_result)
    end

    it 'returns a success response' do
      get :client
      expect(response).to be_successful
    end

    it 'calls GithubReleaseStatsService.call and assigns result to @client_download_stats' do
      get :client
      expect(GithubReleaseStatsService).to have_received(:call)
    end
  end
end
