class AlbionOnlineUpdateCheckService

  def self.check
    current_version = current_live_version
    last_version = REDIS['west'].get('CURRENT_ALBION_ONLINE_VERSION')

    if last_version.nil? || current_version != last_version
      REDIS['west'].set('CURRENT_ALBION_ONLINE_VERSION', current_version)
      # alert discord if the version is different, but last_version is not nil
      alert_discord(current_version) if !last_version.nil? && current_version != last_version
    end
  end

  def self.current_live_version
    url = "https://live.albiononline.com/autoupdate/manifest.xml"
    response = HTTParty.get(url)
    xml = Nokogiri::XML(response.body)
    xml.xpath('//patchsitemanifest/albiononline/win32/fullinstall/@version').to_s
  end

  def self.alert_discord(new_version)
    # send a message to the discord channel
    url = ENV['DISCORD_WEBHOOK_URL']
    message = "TESTING: Albion Online has been updated to version #{new_version}."
    message += ENV['ADDITIONAL_MESSAGE_CONTENT'] unless ENV['ADDITIONAL_MESSAGE_CONTENT'].nil?
    HTTParty.post(url, body: { content: message }.to_json, headers: { 'Content-Type' => 'application/json' })
  end
end