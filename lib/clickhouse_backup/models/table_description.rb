# frozen_string_literal: true

require 'clickhouse_backup/models/clickhouse_table'
require 'clickhouse_backup/models/partition_description'

module ClickhouseBackup
  module Models
    # Model connected to system.tables
    #
    # Describes existing database tables
    #
    # Fields:
    # * database String
    # * name String
    # * engine String
    # * is_temporary UInt8
    # * data_paths String
    # * metadata_path String
    class TableDescription < ClickhouseBackup::Models::ClickhouseTable
      self.table_name = 'system.tables'

      attr_reader :create_query

      # Class methods
      module ClassMethods
        attr_accessor :ignored_databases

        def all
          each.to_a.select(&:freezable?)
        end
      end
      extend ClassMethods

      def partitions
        return @__partition_descriptions if @__partition_descriptions

        @__partition_descriptions = PartitionDescription.for_table(self)
        @__partition_descriptions
      end

      def freeze
        partitions.each(&:freeze)
      end

      def freezable?
        return false if data_paths.empty? || ClickhouseBackup.ignored_databases.include?(database)

        begin
          query = "SHOW CREATE TABLE #{database}.#{name}"
          @create_query = ClickHouse.connection.select_all(query).first['statement']
        rescue => e
          puts e.inspect
          return false
        end

        true
      end
    end
  end
end
