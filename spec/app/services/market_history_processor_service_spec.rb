describe MarketHistoryProcessorService, type: :service do

  describe '.ticks_to_epoch' do

    it 'converts ticks to epoch' do
      ticks = 638486424000000000
      expected_datetime = DateTime.parse("2023-04-11 22:00:00 +0000")
      expect(MarketHistoryProcessorService.ticks_to_epoch(ticks)).to eq(expected_datetime)
    end
  end

end