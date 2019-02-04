# frozen_string_literal: true

module ClickhouseBackup
  # Command line interface parser
  module CLI
    # Class methods for module
    module ClassMethods
      def config_path
        relative_path = realtive_config_path
        abs_path = abs_config_path

        return relative_path if relative_path&.exist? && relative_path&.file?

        return abs_path if abs_path&.exist? && abs_path&.file?

        show_help
      end

      private

      def realtive_config_path
        return nil unless ARGV[0]

        ClickhouseBackup.root.join.expand_path
      end

      def abs_config_path
        return nil unless ARGV[0]

        Pathname.new(ARGV[0]).expand_path
      end

      def show_help
        puts "Configuration file not specified.\n"
        puts "Usage:\n\nexe/clickhouse_backup path_to_config\n\n"
        puts 'Example configuration files located at example\config.yml.example'
        exit(1)
      end
    end

    extend ClassMethods
  end
end
