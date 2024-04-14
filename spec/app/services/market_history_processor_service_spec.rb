describe MarketHistoryProcessorService, type: :service do

  describe '.ticks_to_time' do

    it 'converts ticks to time object' do
      ticks = 638486460000000000
      expected_datetime = DateTime.parse("2024-04-13 23:00:00 +0000")
      expect(MarketHistoryProcessorService.ticks_to_time(ticks)).to eq(expected_datetime)
    end

    xit 'process needs testing here'
  end

end