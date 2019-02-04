# frozen_string_literal: true

require 'clickhouse_backup/models/clickhouse_table'

module ClickhouseBackup
  module Models
    # Model connected to system.tables
    #
    # Describes existing database tables partitions
    #
    # Fields:
    # partition String
    # name String
    # active UInt8
    # marks UInt64
    # rows UInt64
    # bytes_on_disk UInt64
    # data_compressed_bytes UInt64
    # data_uncompressed_bytes UInt64
    # marks_bytes UInt64
    # modification_time DateTime
    # remove_time DateTime
    # refcount UInt32
    # min_date Date
    # max_date Date
    # min_block_number Int64
    # max_block_number Int64
    # level UInt32
    # primary_key_bytes_in_memory UInt64
    # primary_key_bytes_in_memory_allocated UInt64
    # database String
    # table String
    # engine String
    # path String
    # bytes UInt64 alias bytes_on_disk
    # marks_size UInt64 alias marks_bytes
    class PartitionDescription < ClickhouseBackup::Models::ClickhouseTable
      self.table_name = 'system.parts'

      attr_reader :attach_sql

      # Class methods
      module ClassMethods
        attr_accessor :ignored_databases

        def for_table(table)
          all
            .where(active: 1, database: table.database, table: table.name)
            .to_a
            .uniq(&:partition)
        end
      end
      extend ClassMethods

      def freeze
        query = "ALTER TABLE #{database}.#{table} FREEZE PARTITION ID '#{partition}'"
        Clickhouse.connection.execute query
        @attach_sql = "ALTER TABLE #{database}.#{table} ATTACH PARTITION #{partition};\n"
      rescue Clickhouse::QueryError => e
        ClickhouseBackup.logger.debug { "Cannot freeze #{database}.#{table}.#{partition} cause #{e.message}" }
      end
    end
  end
end
