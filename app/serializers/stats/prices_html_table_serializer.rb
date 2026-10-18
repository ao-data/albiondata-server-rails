module Stats
  class PricesHtmlTableSerializer
    FIELDS = [:item_id, :city, :quality, :sell_price_min, :sell_price_min_date, :sell_price_max,
              :sell_price_max_date, :buy_price_min, :buy_price_min_date, :buy_price_max, :buy_price_max_date]

    def self.call(sorted_results)
      rows = []
      rows << "<head><style>table, th, td {border: 1px solid black;border-collapse: collapse;}</style></head><body>"
      rows << "<table style='width:100%'>"
      rows << "<tr>"
      FIELDS.each do |f|
        rows << "<th>#{f.to_s}</th>"
      end
      rows << "</tr>"

      default_date = DateTime.new(0001, 1, 1, 0, 0, 0).strftime('%Y-%m-%dT%H:%M:%S')
      sorted_results.each do |r|
        row = []
        row << "<tr>"
        FIELDS.each do |f|
          row << (r[f] == 0 || r[f] == default_date ? "<td></td>" : "<td>#{r[f]}</td>")
        end
        row << "</tr>"
        rows << row.join('')
      end
      rows << "</table></body>"
      rows.join('')
    end
  end
end
