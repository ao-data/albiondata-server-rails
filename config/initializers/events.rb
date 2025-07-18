ActiveSupport::Notifications.subscribe /metrics\./ do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  ActiveSupportNotificationWorker.perform_async(event.name, event.payload.to_json)
end