describe AlbionOnlineUpdateCheckService, type: :service do

  describe '#check' do
    describe "last_version doesnt exist" do
      it 'checks the current version' do
        expect(described_class).to receive(:current_live_version).and_return('1.0.0')
        expect(REDIS['west']).to receive(:get).with('CURRENT_ALBION_ONLINE_VERSION').and_return(nil)
        expect(REDIS['west']).to receive(:set).with('CURRENT_ALBION_ONLINE_VERSION', '1.0.0')
        expect(described_class).to_not receive(:alert_discord)
        described_class.check
      end
    end

    describe "version changed" do
      it 'checks the current version' do
        expect(described_class).to receive(:current_live_version).and_return('1.0.1')
        expect(REDIS['west']).to receive(:get).with('CURRENT_ALBION_ONLINE_VERSION').and_return('1.0.0')
        expect(REDIS['west']).to receive(:set).with('CURRENT_ALBION_ONLINE_VERSION', '1.0.1')
        expect(described_class).to receive(:alert_discord).with('1.0.1')
        described_class.check
      end
    end
  end

  describe '#current_live_version' do
    it 'returns the current live version' do
      expect(HTTParty).to receive(:get).with("https://live.albiononline.com/autoupdate/manifest.xml").and_return(double(body: "<patchsitemanifest><albiononline><win32><fullinstall version='1.0.0' /></win32></albiononline></patchsitemanifest>"))
      expect(described_class.current_live_version).to eq('1.0.0')
    end
  end

  describe '#alert_discord' do
    it 'sends a message to discord' do
      expect(ENV).to receive(:[]).with('DISCORD_WEBHOOK_URL').and_return('webhook_url')
      expect(ENV).to receive(:[]).with('ADDITIONAL_MESSAGE_CONTENT').exactly(2).times.and_return('additional_content')
      expect(HTTParty).to receive(:post).with('webhook_url', body: { content: "TESTING: Albion Online has been updated to version 1.0.0.additional_content" }.to_json, headers: { 'Content-Type' => 'application/json' })
      described_class.alert_discord('1.0.0')
    end
  end
end
