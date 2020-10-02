# frozen_string_literal: true

require 'click_house'

module ClickhouseBackup
  module Models
    # MiniORM simple query interface
    class Query
      include Enumerable

      attr_accessor :table
      attr_accessor :query_options

      def each
        query = build_query

        res = ClickHouse.connection.select_all(query)

        puts "Query: ${query}"
        puts "Res: ${res}"

        res.each do |x|
          yield parse_raw_row(x)
        end
      end

      def where(options)
        query = Query.new
        query.table = table

        query.query_options = query_options || {}

        where_hash = ((query_options || {})[:where] || {})
        query.query_options[:where] = where_hash.merge(options)

        query
      end

      private

      def parse_raw_row(raw_row)
        rec = table.new

        raw_row.each_with_index do |val, i|
          rec.send("#{fields[i]}=", val)
        end

        rec
      end

      def build_query
        where_query = where_query_from_options(query_options)

        query = {
          from: table.table_name,
          select: select_fields_from_options(query_options)
        }

        query[:where] = where_query if where_query
        query
      end

      def fields
        table.fields
      end

      def where_query_from_options(options)
        return nil unless options

        options[:where]
      end

      def select_fields_from_options(options)
        return fields.join(',') unless options

        fields_from_select(options).join(',')
      end

      def fields_from_select(select_option)
        if select_option == '*'
          fields
        elsif select_option.is_a?(Array)
          unknown_fields = select_option - fields
          raise "Unknown fields in query: #{unknown_fields.join(', ')}" if unknown_fields

          select_option
        else
          fields
        end
      end
    end
  end
end
