MYSQL_WEST_URL=$MYSQL_EAST_URL bundle exec rake db:migrate
MYSQL_WEST_URL=$MYSQL_EUROPE_URL bundle exec rake db:migrate
bundle exec rake db:migrate

