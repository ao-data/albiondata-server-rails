require 'rails_helper'

RSpec.describe ApplicationController, :type => :controller do

  before do
    @request.host = "west.example.com"

    [:east, :west, :europe].each do |db|
      Multidb.use(db) do
        MarketOrder.delete_all
      end
    end
  end

  it 'east db items are not available in west/europe dbs' do
    Multidb.use(:east) do
      create(:market_order)
    end

    Multidb.use(:west) do
      expect(MarketOrder.all).to be_empty
    end

    Multidb.use(:europe) do
      expect(MarketOrder.all).to be_empty
    end
  end

  it 'west db items are not available in east/europe dbs' do
    Multidb.use(:west) do
      create(:market_order)
    end

    Multidb.use(:east) do
      expect(MarketOrder.all).to be_empty
    end

    Multidb.use(:europe) do
      expect(MarketOrder.all).to be_empty
    end
  end

  it 'europe db items are not available in east/west dbs' do
    Multidb.use(:europe) do
      create(:market_order)
    end

    Multidb.use(:east) do
      expect(MarketOrder.all).to be_empty
    end

    Multidb.use(:west) do
      expect(MarketOrder.all).to be_empty
    end
  end

  describe 'when using subdomains' do
    describe 'and there is data for that subdomain' do
      it 'returns the data for that subdomain' do
        Multidb.use(:east) do
          create(:market_order)
        end

        @request.host = "east.example.com"
        get :test
        expect(JSON.parse(response.body)['orders'].length).to eq(1)
      end
    end

    it 'does not return data for other subdomains' do
      Multidb.use(:east) do
        create(:market_order)
      end

      Multidb.use(:europe) do
        create(:market_order)
      end

      @request.host = "west.example.com"
      get :test
      expect(JSON.parse(response.body)['orders']).to be_empty
    end

    it 'returns data for east subdomain' do
      Multidb.use(:east) do
        create(:market_order)
      end

      @request.host = "east.example.com"
      get :test
      expect(JSON.parse(response.body)['orders'].length).to eq(1)
    end

    it 'returns data for europe subdomain' do
      Multidb.use(:europe) do
        create(:market_order)
      end

      @request.host = "europe.example.com"
      get :test
      expect(JSON.parse(response.body)['orders'].length).to eq(1)
    end

    it 'returns data for west subdomain' do
      Multidb.use(:west) do
        create(:market_order)
      end

      @request.host = "west.example.com"
      get :test
      expect(JSON.parse(response.body)['orders'].length).to eq(1)
    end

    it 'defaults to west if unknown subdomain' do
      Multidb.use(:west) do
        create(:market_order)
      end

      Multidb.use(:east) do
        create(:market_order)
        create(:market_order)
      end

      Multidb.use(:europe) do
        create(:market_order)
        create(:market_order)
      end

      @request.host = "unknown.example.com"
      get :test
      expect(JSON.parse(response.body)['orders'].length).to eq(1)
    end

    it 'returns the correct server_id with sub-subdomains' do
      @request.host = "pow.west.example.com"
      expect(controller.server_id).to eq("west")
    end
  end
end