class ActiveSupportNotificationService
  def self.process(name, payload)

    case name
    when 'metrics.market_order_dedupe_service'
      market_order_dedupe_service(payload)
    when 'metrics.market_history_dedupe_service'
      market_history_dedupe_service(payload)
    when 'metrics.gold_dedupe_service'
      gold_dedupe_service(payload)
    else
      Rails.logger.warn "ActiveSupportNotificationService: Unhandled event: #{name}"
    end
  end

  def self.market_order_dedupe_service(payload)
    puts "Market Order Dedupe Service Metrics: #{payload}"
  end

  def self.market_history_dedupe_service(payload)
    puts "Market History Dedupe Service Metrics: #{payload}"
  end

  def self.gold_dedupe_service(payload)
    puts "Gold Dedupe Service Metrics: #{payload}"
  end
end