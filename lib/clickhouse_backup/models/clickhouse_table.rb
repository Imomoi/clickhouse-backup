# frozen_string_literal: true

require 'clickhouse'
require 'clickhouse_backup/models/query'

module ClickhouseBackup
  module Models
    # Mini ORM base class for wiring models to clickhouse tables
    class ClickhouseTable
      def self.inherited(base)
        base.extend Enumerable
        base.extend ClassMethods
      end

      # Class methods
      module ClassMethods
        def table_name=(table_name)
          @___table_name = table_name
        end

        def table_name
          @___table_name
        end

        def fields
          @___fields
        end

        def describe
          return if @___fields

          res = ClickHouse.connection.select_all 'DESCRIBE TABLE ' + table_name
          fields = res.map { |x| x[0] }

          class_eval do
            fields.each do |f|
              attr_accessor f
            end
          end

          @___fields = fields
        end

        def each(&block)
          describe
          query = Query.new
          query.table = self

          if block_given?
            query.each(&block)
          else
            query
          end
        end

        def all
          each
        end

        def where(options)
          each.where(options)
        end
      end
    end
  end
end
