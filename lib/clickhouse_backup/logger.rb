# frozen_string_literal: true

module ClickhouseBackup
  # Logger module
  module Logger
    def logger
      return @___logger if @___logger

      @___logger = ::Logger.new(output_stream, 7, 10 * 1024 * 1024)

      configure_log_level
      @___logger
    end

    private

    def configure_log_level
      @___logger.level = Object.const_get("::Logger::#{configuration['log_level']}")
    rescue NameError => e
      @___logger.level = ::Logger::DEBUG
      @___logger.warn e.message
      @___logger.warn { 'Incorrect log level. Possible values: DEBUG, INFO, WARN, ERROR' }
    end

    def output_stream
      case configuration['log_output']
      when 'file'
        File.join(ClickhouseBackup.configuration['backup']['temp-file-location'] || '~', 'clickhouse_backup.log')
      else
        STDOUT
      end
    end
  end
end
