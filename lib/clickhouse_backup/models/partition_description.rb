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
          if !@___fields
            @___fields = ['partition', 'database', 'table']
            @___fields.each {|x| attr_accessor x}
          end

          all
            .where("active and database = '#{table.database}' and table = '#{table.name}'")
            .to_a
            .uniq(&:partition)
        end
      end
      extend ClassMethods

      def freeze
        query = if partition == 'tuple()'
                  "ALTER TABLE #{database}.#{table} FREEZE"
                else
                  "ALTER TABLE #{database}.#{table} FREEZE PARTITION #{partition}"
                end
        ClickHouse.connection.execute query
      rescue => e
        ClickhouseBackup.logger.debug { "Cannot freeze #{database}.#{table}.#{partition} cause #{e.message}" }
      end
    end
  end
end
