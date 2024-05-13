MYSQL_WEST_URL=$MYSQL_EAST_URL bundle exec rake db:setup
MYSQL_WEST_URL=$MYSQL_EUROPE_URL bundle exec rake db:setup
bundle exec rake db:setup

