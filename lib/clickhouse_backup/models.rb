# frozen_string_literal: true

require 'clickhouse'

Dir[File.join(__dir__, 'models', '*.rb')].each do |f|
  require f
end

module ClickhouseBackup
  # Clickhouse database models
  module Models
  end
end
