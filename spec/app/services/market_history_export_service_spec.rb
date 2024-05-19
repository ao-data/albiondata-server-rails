describe MarketHistoryExportService, type: :service do

  describe '#export' do
    describe "default export" do
      it 'runs the correct commands' do
        Timecop.freeze(DateTime.parse('2024-07-02'))
        expected_cmd = [
          'mysqldump',
          "-h mysql",
          "-uroot",
          "-proot",
          "--compact",
          "--no-create-info",
          "--skip-create-options",
          "--skip-add-drop-table",
          "--skip-add-drop-database",
          "-B aodp",
          "--tables market_history",
          "--where=\"\\`timestamp\\` between '2024-01-01 00:00:00' and '2024-01-31 23:59:59'\"",
          "> /tmp/west/market_history_2024_01.sql"
        ]

        expect(described_class).to receive(:run_cmd).with(expected_cmd)
        expect(described_class).to receive(:run_cmd).with('gzip /tmp/west/market_history_2024_01.sql')
        described_class.export('west')
      end
    end

    describe "with year/month provided" do
      it 'runs the correct commands' do
        expected_cmd = [
          'mysqldump',
          "-h mysql",
          "-uroot",
          "-proot",
          "--compact",
          "--no-create-info",
          "--skip-create-options",
          "--skip-add-drop-table",
          "--skip-add-drop-database",
          "-B aodp",
          "--tables market_history",
          "--where=\"\\`timestamp\\` between '2023-12-01 00:00:00' and '2023-12-31 23:59:59'\"",
          "> /tmp/west/market_history_2023_12.sql"
        ]

        expect(described_class).to receive(:run_cmd).with(expected_cmd)
        expect(described_class).to receive(:run_cmd).with('gzip /tmp/west/market_history_2023_12.sql')
        described_class.export('west', "2023", 12)
      end
    end

    describe "env vars" do
      before do
        expect(ENV).to receive(:[]).with('MYSQL_WEST_HOST').and_return('west_host')
        expect(ENV).to receive(:[]).with('MYSQL_WEST_USER').and_return('west_user')
        expect(ENV).to receive(:[]).with('MYSQL_WEST_PASS').and_return('west_pass')
        expect(ENV).to receive(:[]).with('MYSQL_WEST_DB').and_return('west_db')
        expect(ENV).to receive(:[]).with('MYSQL_WEST_EXPORT_PATH').and_return('/tmp/west_path')

        expect(ENV).to receive(:[]).with('MYSQL_EAST_HOST').and_return('east_host')
        expect(ENV).to receive(:[]).with('MYSQL_EAST_USER').and_return('east_user')
        expect(ENV).to receive(:[]).with('MYSQL_EAST_PASS').and_return('east_pass')
        expect(ENV).to receive(:[]).with('MYSQL_EAST_DB').and_return('east_db')
        expect(ENV).to receive(:[]).with('MYSQL_EAST_EXPORT_PATH').and_return('/tmp/east_path')

        expect(ENV).to receive(:[]).with('MYSQL_EUROPE_HOST').and_return('europe_host')
        expect(ENV).to receive(:[]).with('MYSQL_EUROPE_USER').and_return('europe_user')
        expect(ENV).to receive(:[]).with('MYSQL_EUROPE_PASS').and_return('europe_pass')
        expect(ENV).to receive(:[]).with('MYSQL_EUROPE_DB').and_return('europe_db')
        expect(ENV).to receive(:[]).with('MYSQL_EUROPE_EXPORT_PATH').and_return('/tmp/europe_path')
      end

      describe "west" do
        it 'runs the correct commands' do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          expected_cmd = [
            'mysqldump',
            "-h west_host",
            "-uwest_user",
            "-pwest_pass",
            "--compact",
            "--no-create-info",
            "--skip-create-options",
            "--skip-add-drop-table",
            "--skip-add-drop-database",
            "-B west_db",
            "--tables market_history",
            "--where=\"\\`timestamp\\` between '2024-01-01 00:00:00' and '2024-01-31 23:59:59'\"",
            "> /tmp/west_path/market_history_2024_01.sql"
          ]

          expect(described_class).to receive(:run_cmd).with(expected_cmd)
          expect(described_class).to receive(:run_cmd).with('gzip /tmp/west_path/market_history_2024_01.sql')
          described_class.export('west')
        end
      end

      describe "east" do
        it 'runs the correct commands' do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          expected_cmd = [
            'mysqldump',
            "-h east_host",
            "-ueast_user",
            "-peast_pass",
            "--compact",
            "--no-create-info",
            "--skip-create-options",
            "--skip-add-drop-table",
            "--skip-add-drop-database",
            "-B east_db",
            "--tables market_history",
            "--where=\"\\`timestamp\\` between '2024-01-01 00:00:00' and '2024-01-31 23:59:59'\"",
            "> /tmp/east_path/market_history_2024_01.sql"
          ]

          expect(described_class).to receive(:run_cmd).with(expected_cmd)
          expect(described_class).to receive(:run_cmd).with('gzip /tmp/east_path/market_history_2024_01.sql')
          described_class.export('east')
        end
      end

      describe "europe" do
        it 'runs the correct commands' do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          expected_cmd = [
            'mysqldump',
            "-h europe_host",
            "-ueurope_user",
            "-peurope_pass",
            "--compact",
            "--no-create-info",
            "--skip-create-options",
            "--skip-add-drop-table",
            "--skip-add-drop-database",
            "-B europe_db",
            "--tables market_history",
            "--where=\"\\`timestamp\\` between '2024-01-01 00:00:00' and '2024-01-31 23:59:59'\"",
            "> /tmp/europe_path/market_history_2024_01.sql"
          ]

          expect(described_class).to receive(:run_cmd).with(expected_cmd)
          expect(described_class).to receive(:run_cmd).with('gzip /tmp/europe_path/market_history_2024_01.sql')
          described_class.export('europe')
        end
      end
    end
  end
end
