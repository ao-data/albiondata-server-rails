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
        # Pretend its August 2nd, 2024
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
      before do
        allow(described_class).to receive(:count_month).and_return(1)
        allow(described_class).to receive(:count_sql_records).and_return(1)
        allow(described_class).to receive(:count_gz_records).and_return(1)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql').and_return(false, true)
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql.gz').and_return(false, true)
      end

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
          "--skip-extended-insert",
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
      before do
        allow(described_class).to receive(:count_month).and_return(1)
        allow(described_class).to receive(:count_sql_records).and_return(1)
        allow(described_class).to receive(:count_gz_records).and_return(1)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2023_12.sql').and_return(false, true)
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2023_12.sql.gz').and_return(false, true)
      end

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
          "--skip-extended-insert",
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

    describe 'with delete_data set to true' do
      before do
        allow(described_class).to receive(:run_cmd)
        allow(described_class).to receive(:count_month).and_return(1)
        allow(described_class).to receive(:count_sql_records).and_return(1)
        allow(described_class).to receive(:count_gz_records).and_return(1)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql').and_return(false, true)
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql.gz').and_return(false, true)
      end

      it 'calls delete_month after all validations pass' do
        expect(described_class).to receive(:delete_month).with('west', '2024', '01')
        described_class.export('west', '2024', "01", true)
      end
    end

    describe "validation failures" do
      before do
        allow(described_class).to receive(:run_cmd)
        allow(described_class).to receive(:count_month).and_return(100)
        allow(described_class).to receive(:count_sql_records).and_return(100)
        allow(described_class).to receive(:count_gz_records).and_return(100)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql').and_return(false, true)
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql.gz').and_return(false, true)
      end

      it 'raises when the mysqldump file was not created' do
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql').and_return(false)

        expect { described_class.export('west', '2024', '01') }
          .to raise_error(RuntimeError, /Export failed.*not created/)
      end

      it 'raises when the SQL file record count does not match the database count' do
        allow(described_class).to receive(:count_sql_records).and_return(99)

        expect { described_class.export('west', '2024', '01') }
          .to raise_error(RuntimeError, /Export validation failed.*99.*100/)
      end

      it 'raises when the gzip file was not created' do
        allow(File).to receive(:exist?).with('/tmp/west/market_history_2024_01.sql.gz').and_return(false)

        expect { described_class.export('west', '2024', '01') }
          .to raise_error(RuntimeError, /Compression failed.*not created/)
      end

      it 'raises when the gzipped file record count does not match the database count' do
        allow(described_class).to receive(:count_gz_records).and_return(99)

        expect { described_class.export('west', '2024', '01') }
          .to raise_error(RuntimeError, /Gzip validation failed.*99.*100/)
      end

      it 'does not call delete_month when export validation fails' do
        allow(described_class).to receive(:count_sql_records).and_return(99)

        expect(described_class).not_to receive(:delete_month)
        expect { described_class.export('west', '2024', '01', true) }.to raise_error(RuntimeError)
      end

      it 'does not call delete_month when gzip validation fails' do
        allow(described_class).to receive(:count_gz_records).and_return(99)

        expect(described_class).not_to receive(:delete_month)
        expect { described_class.export('west', '2024', '01', true) }.to raise_error(RuntimeError)
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
        before do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          allow(described_class).to receive(:run_cmd).and_return(nil)
          allow(described_class).to receive(:count_month).and_return(1)
          allow(described_class).to receive(:count_sql_records).and_return(1)
          allow(described_class).to receive(:count_gz_records).and_return(1)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with('/tmp/west_path/market_history_2024_01.sql').and_return(false, true)
          allow(File).to receive(:exist?).with('/tmp/west_path/market_history_2024_01.sql.gz').and_return(false, true)
        end

        after { Timecop.return }

        it 'runs the correct commands' do
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
            "--skip-extended-insert",
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
          FileUtils.remove_dir('/tmp/west_path', true) if File.exist?('/tmp/west_path')
          described_class.export('west')
          expect(File.directory?('/tmp/west_path')).to be true
        end

        it 'deletes the export file if it exists' do
          allow(File).to receive(:exist?).with('/tmp/west_path/market_history_2024_01.sql').and_return(true, true)

          expect(File).to receive(:delete).with('/tmp/west_path/market_history_2024_01.sql')
          described_class.export('west')
        end

        it 'deletes the gz file if it exists' do
          allow(File).to receive(:exist?).with('/tmp/west_path/market_history_2024_01.sql.gz').and_return(true, true)

          expect(File).to receive(:delete).with('/tmp/west_path/market_history_2024_01.sql.gz')
          described_class.export('west')
        end
      end

      describe "east" do
        before do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          allow(described_class).to receive(:count_month).and_return(1)
          allow(described_class).to receive(:count_sql_records).and_return(1)
          allow(described_class).to receive(:count_gz_records).and_return(1)
          allow(File).to receive(:exist?).with('/tmp/east_path/market_history_2024_01.sql').and_return(false, true)
          allow(File).to receive(:exist?).with('/tmp/east_path/market_history_2024_01.sql.gz').and_return(false, true)
        end

        after { Timecop.return }

        it 'runs the correct commands' do
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
            "--skip-extended-insert",
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
        before do
          Timecop.freeze(DateTime.parse('2024-07-02'))
          allow(described_class).to receive(:count_month).and_return(1)
          allow(described_class).to receive(:count_sql_records).and_return(1)
          allow(described_class).to receive(:count_gz_records).and_return(1)
          allow(File).to receive(:exist?).with('/tmp/europe_path/market_history_2024_01.sql').and_return(false, true)
          allow(File).to receive(:exist?).with('/tmp/europe_path/market_history_2024_01.sql.gz').and_return(false, true)
        end

        after { Timecop.return }

        it 'runs the correct commands' do
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
            "--skip-extended-insert",
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

  describe '#export_month' do
    it "returns ['2024', '01'] when the date is July 2024" do
      Timecop.freeze(DateTime.parse('2024-07-02'))
      expect(described_class.export_month).to eq(['2024', '01'])
    end

    it "returns ['2024', '02'] when the date is August 2024" do
      Timecop.freeze(DateTime.parse('2024-08-02'))
      expect(described_class.export_month).to eq(['2024', '02'])
    end
  end

  describe '#count_month' do
    it 'returns the count of records for the given month' do
      Multidb.use(:west) do
        create(:market_history, timestamp: Time.new(2023, 12, 1))
        create(:market_history, timestamp: Time.new(2024, 1, 1))
        create(:market_history, timestamp: Time.new(2024, 1, 15))
        create(:market_history, timestamp: Time.new(2024, 2, 1))
      end
      expect(described_class.count_month('west', '2024', '01')).to eq(2)
    end

    it 'returns 0 when no records exist for the given month' do
      expect(described_class.count_month('west', '2099', '01')).to eq(0)
    end
  end

  describe '#count_sql_records' do
    it 'counts INSERT INTO lines in a sql file' do
      Tempfile.create(['test', '.sql']) do |f|
        f.write("INSERT INTO `market_history` VALUES (1,'a');\nINSERT INTO `market_history` VALUES (2,'b');\n")
        f.close
        expect(described_class.count_sql_records(f.path)).to eq(2)
      end
    end

    it 'counts a single INSERT INTO line' do
      Tempfile.create(['test', '.sql']) do |f|
        f.write("INSERT INTO `market_history` VALUES (1,'a');\n")
        f.close
        expect(described_class.count_sql_records(f.path)).to eq(1)
      end
    end

    it 'returns 0 for a file with no INSERT statements' do
      Tempfile.create(['test', '.sql']) do |f|
        f.write("-- some comment\n-- another comment\n")
        f.close
        expect(described_class.count_sql_records(f.path)).to eq(0)
      end
    end
  end

  describe '#count_gz_records' do
    it 'counts INSERT INTO lines in a gzipped sql file' do
      Tempfile.create(['test', '.sql']) do |f|
        f.write("INSERT INTO `market_history` VALUES (1,'a');\nINSERT INTO `market_history` VALUES (2,'b');\n")
        f.close
        `gzip -k #{f.path}`
        gz_path = "#{f.path}.gz"
        expect(described_class.count_gz_records(gz_path)).to eq(2)
        File.delete(gz_path) if File.exist?(gz_path)
      end
    end

    it 'returns 0 for a gzipped file with no INSERT statements' do
      Tempfile.create(['test', '.sql']) do |f|
        f.write("-- no inserts here\n")
        f.close
        `gzip -k #{f.path}`
        gz_path = "#{f.path}.gz"
        expect(described_class.count_gz_records(gz_path)).to eq(0)
        File.delete(gz_path) if File.exist?(gz_path)
      end
    end
  end

  describe '#delete_month' do
    it 'deletes data if delete_data is true' do
      Timecop.freeze(Time.new(2024, 1, 1)) do
        Multidb.use(:west) do
          create(:market_history, timestamp: Time.new(2023, 12, 1))
          create(:market_history, timestamp: Time.new(2024, 1, 1))
          create(:market_history, timestamp: Time.new(2024, 2, 1))
        end
        described_class.delete_month('west', '2024', '01')
        Multidb.use(:west) do
          expect(MarketHistory.count).to eq(2)
          expect(MarketHistory.where("timestamp between '2024-01-01' and '2024-01-31'").count).to eq(0)
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
