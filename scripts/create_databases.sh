MYSQL_WEST_URL=$MYSQL_EAST_URL bundle exec rake db:create
MYSQL_WEST_URL=$MYSQL_EUROPE_URL bundle exec rake db:create
bundle exec rake db:create

