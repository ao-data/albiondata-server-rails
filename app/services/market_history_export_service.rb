class MarketHistoryExportService

  def self.run_cmd(cmd)
    puts "MarketHistoryExportService::run_cmd: cmd: #{cmd}"
    `#{cmd}`
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

  def self.delete_month(year = nil, month = nil)

  end

  def self.export(server_id, year = nil, month = nil)
    year, month = export_month(year, month) if year.nil? || month.nil?

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

    export_filename = "#{export_dir}/market_history_#{start_datetime.strftime('%Y_%m')}.sql"

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
      "-B #{db}",
      '--tables market_history',
      "--where=\"\\\`timestamp\\\` between '#{start_datetime_str}' and '#{end_datetime_str}'\"",
      "> #{export_filename}"
    ]
    run_cmd(cmd)

    cmd = "gzip #{export_filename}"
    run_cmd(cmd)
  end
end