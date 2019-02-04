# frozen_string_literal: true

require 'clickhouse_backup/models/clickhouse_table'

module ClickhouseBackup
  module Models
    # Model connected to system.parts
    class PartitionDescription < ClickhouseBackup::Models::ClickhouseTable
      self.table_name = 'system.parts'

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
      rescue Clickhouse::QueryError => e
        ClickhouseBackup.logger.debug { "Cannot freeze #{database}.#{table}.#{partition} cause #{e.message}" }
      end
    end
  end
end
