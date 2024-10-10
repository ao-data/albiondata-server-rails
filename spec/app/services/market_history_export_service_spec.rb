require 'rails_helper'

RSpec.describe MarketHistoryExportService, type: :service do

  describe '#export' do
    describe "integration tests" do
      before do
        ENV['MYSQL_WEST_DB'] = 'aodp_test'
      end

      after do
        ENV['MYSQL_WEST_DB'] = 'aodp'
      end

      it 'only includes the correct data' do
        # Pretend its Auguest 2nd, 2024
        Timecop.freeze(DateTime.parse('2024-08-02'))

        # create records before, including and after our target month
        ['01', '02', '03', '04'].each do |month|
          create(:market_history, timestamp: DateTime.parse("2024-#{month}-01 00:00:00"))
        end

        # export the data
        described_class.export('west')

        # unzip tmp file
        `gunzip /tmp/west/market_history_2024_02.sql.gz`

        # check the contents of the file
        contents = File.read('/tmp/west/market_history_2024_02.sql')
        expect(contents).to include('INSERT INTO `market_history` VALUES')
        expect(contents).to_not include('2024-01-01 00:00:00')
        expect(contents).to include('2024-02-01 00:00:00')
        expect(contents).to_not include('2024-03-01 00:00:00')
        expect(contents).to_not include('2024-04-01 00:00:00')

        # cleanup
        `rm -f /tmp/west/market_history_2024_02.sql`
      end
    end

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
        expect(described_class).to receive(:run_cmd).with(['gzip', '/tmp/west/market_history_2024_01.sql'])
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
        expect(described_class).to receive(:run_cmd).with(['gzip', '/tmp/west/market_history_2023_12.sql'])
        described_class.export('west', "2023", 12)
      end
    end

    describe "env vars" do
      before do
        # Note: This is a hacky way to test this, but it works. We need to set the ENV vars to the correct values.
        %w[WEST EAST EUROPE].each do |region|
          instance_variable_set("@old_mysql_#{region.downcase}_host", ENV["MYSQL_#{region}_HOST"])
          instance_variable_set("@old_mysql_#{region.downcase}_user", ENV["MYSQL_#{region}_USER"])
          instance_variable_set("@old_mysql_#{region.downcase}_pass", ENV["MYSQL_#{region}_PASS"])
          instance_variable_set("@old_mysql_#{region.downcase}_db", ENV["MYSQL_#{region}_DB"])
          instance_variable_set("@old_mysql_#{region.downcase}_export_path", ENV["MYSQL_#{region}_EXPORT_PATH"])

          ENV["MYSQL_#{region}_HOST"] = "#{region.downcase}_host"
          ENV["MYSQL_#{region}_USER"] = "#{region.downcase}_user"
          ENV["MYSQL_#{region}_PASS"] = "#{region.downcase}_pass"
          ENV["MYSQL_#{region}_DB"] = "#{region.downcase}_db"
          ENV["MYSQL_#{region}_EXPORT_PATH"] = "/tmp/#{region.downcase}_path"
        end
      end

      after do
        %w[WEST EAST EUROPE].each do |region|
          ENV["MYSQL_#{region}_HOST"] = instance_variable_get("@old_mysql_#{region.downcase}_host")
          ENV["MYSQL_#{region}_USER"] = instance_variable_get("@old_mysql_#{region.downcase}_user")
          ENV["MYSQL_#{region}_PASS"] = instance_variable_get("@old_mysql_#{region.downcase}_pass")
          ENV["MYSQL_#{region}_DB"] = instance_variable_get("@old_mysql_#{region.downcase}_db")
          ENV["MYSQL_#{region}_EXPORT_PATH"] = instance_variable_get("@old_mysql_#{region.downcase}_export_path")
        end
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
          expect(described_class).to receive(:run_cmd).with(['gzip', '/tmp/west_path/market_history_2024_01.sql'])
          described_class.export('west')
        end

        it 'creates the export directory if it does not exist' do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          allow(described_class).to receive(:run_cmd).and_return(nil)
          FileUtils.remove_dir('/tmp/west_path', true) if File.exist?('/tmp/west_path')
          expect(FileUtils).to receive(:mkdir_p).with('/tmp/west_path')
          described_class.export('west')
        end

        it 'deletes the export file if it exists' do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          expect(described_class).to receive(:run_cmd).twice.and_return(nil)
          FileUtils.mkdir_p('/tmp/west_path') unless File.exist?('/tmp/west_path')
          File.write('/tmp/west_path/market_history_2024_01.sql', 'test')
          described_class.export('west')
          expect(File.exist?('/tmp/west_path/market_history_2024_01.sql')).to be false
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
          expect(described_class).to receive(:run_cmd).with(['gzip', '/tmp/east_path/market_history_2024_01.sql'])
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
          expect(described_class).to receive(:run_cmd).with(['gzip', '/tmp/europe_path/market_history_2024_01.sql'])
          described_class.export('europe')
        end
      end
    end
  end

  describe '#run_cmd' do
    it 'runs the command' do
      expect(described_class).to receive(:`).with('ls')
      described_class.run_cmd(['ls'])
    end
  end
end
