class MarketHistoryExportService

  def self.run_cmd(cmd)
    joined_cmd = cmd.join(' ')
    `#{joined_cmd}`
  end

  def self.export_month(year = nil, month = nil)
    if year.nil? && month.nil?
      # 1. we don't count the current month
      # 2. we want to keep 6 full months of data, so 6 months + this month = 7 months
      # 3. but we want to export 1 month sooner so we have a month in case an export is bad and needs reexporting, so 7 -1 = 6 months

      year = (DateTime.now - 6.months).strftime('%Y')
      month = (DateTime.now - 6.months).strftime('%m')

      [year, month]
    end
  end

  def self.delete_month(server_id, year, month)
    Multidb.use(server_id.to_sym) do
      MarketHistory.where("timestamp between ? and ?", Time.new(year, month, 1), Time.new(year, month, 1).end_of_month).delete_all
    end
  end

  def self.count_month(server_id, year, month)
    Multidb.use(server_id.to_sym) do
      MarketHistory.where("timestamp between ? and ?", Time.new(year, month, 1), Time.new(year, month, 1).end_of_month).count
    end
  end

  def self.count_sql_records(sql_file)
    `grep -c "^INSERT INTO" #{sql_file}`.strip.to_i
  end

  def self.count_gz_records(gz_file)
    `gunzip -c #{gz_file} | grep -c "^INSERT INTO"`.strip.to_i
  end

  def self.export(server_id, year = nil, month = nil, delete_data = false)
    year, month = export_month(year, month) if year.nil? || month.nil?

    # Step 1: Build configuration and file paths
    start_datetime = DateTime.parse("#{year}-#{month}-01 00:00:00")
    end_datetime = start_datetime + 1.months - 1.second

    start_datetime_str = start_datetime.strftime('%Y-%m-%d %H:%M:%S')
    end_datetime_str = end_datetime.strftime('%Y-%m-%d %H:%M:%S')

    server_config = {
      'west' => {
        host: ENV['MYSQL_WEST_HOST'],
        user: ENV['MYSQL_WEST_USER'],
        pwd: ENV['MYSQL_WEST_PASS'],
        db: ENV['MYSQL_WEST_DB'],
        export_dir: ENV['MYSQL_WEST_EXPORT_PATH']
      },
      'east' => {
        host: ENV['MYSQL_EAST_HOST'],
        user: ENV['MYSQL_EAST_USER'],
        pwd: ENV['MYSQL_EAST_PASS'],
        db: ENV['MYSQL_EAST_DB'],
        export_dir: ENV['MYSQL_EAST_EXPORT_PATH']
      },
      'europe' => {
        host: ENV['MYSQL_EUROPE_HOST'],
        user: ENV['MYSQL_EUROPE_USER'],
        pwd: ENV['MYSQL_EUROPE_PASS'],
        db: ENV['MYSQL_EUROPE_DB'],
        export_dir: ENV['MYSQL_EUROPE_EXPORT_PATH']
      }
    }

    host, user, pwd, db, export_dir = server_config[server_id].values

    File.directory?(export_dir) || FileUtils.mkdir_p(export_dir)
    export_filename = "#{export_dir}/market_history_#{start_datetime.strftime('%Y_%m')}.sql"

    File.delete(export_filename) if File.exist?(export_filename)
    File.delete("#{export_filename}.gz") if File.exist?("#{export_filename}.gz")

    # Step 2: Export data via mysqldump
    # --skip-extended-insert writes one INSERT per row, enabling reliable record counting
    cmd = [
      'mysqldump',
      "-h #{host}",
      "-u#{user}",
      "-p#{pwd}",
      '--compact',
      '--no-create-info',
      '--skip-create-options',
      '--skip-add-drop-table',
      '--skip-add-drop-database',
      '--skip-extended-insert',
      "-B #{db}",
      '--tables market_history',
      "--where=\"\\\`timestamp\\\` between '#{start_datetime_str}' and '#{end_datetime_str}'\"",
      "> #{export_filename}"
    ]
    run_cmd(cmd)

    raise "Export failed: #{export_filename} was not created" unless File.exist?(export_filename)

    # Step 3: Query DB for expected record count
    db_count = count_month(server_id, year, month)

    # Step 4: Count records in the SQL file and verify against DB
    file_count = count_sql_records(export_filename)
    raise "Export validation failed: SQL file has #{file_count} records but DB has #{db_count} (#{export_filename})" unless file_count == db_count

    # Step 5: Compress the SQL file
    run_cmd(['gzip', export_filename])
    raise "Compression failed: #{export_filename}.gz was not created" unless File.exist?("#{export_filename}.gz")

    # Step 6: Verify the compressed file decompresses and contains the correct record count
    gz_count = count_gz_records("#{export_filename}.gz")
    raise "Gzip validation failed: compressed file has #{gz_count} records but expected #{db_count} (#{export_filename}.gz)" unless gz_count == db_count

    # Step 7: Delete source data only after all integrity checks pass
    delete_month(server_id, year, month) if delete_data
  end
end
