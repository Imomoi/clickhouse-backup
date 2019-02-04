#!/bin/bash

source /usr/local/rvm/environments/default
cd /usr/local/infrastructure.clickhouse_backup/
bundle install
nice -n 10 ruby /usr/local/infrastructure.clickhouse_backup/bin/clickhouse_backup /usr/local/infrastructure.clickhouse_backup/config.yml
