# frozen_string_literal: true

require 'clickhouse'

Clickhouse::Connection::Query::ResultSet.class_eval do
  def parse_date_time_value(value)
    Time.parse(value)
  rescue ArgumentError
    nil
  end
end
