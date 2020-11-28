# frozen_string_literal: true

require 'click_house'
require 'logger'
require 'yaml'

Dir[File.join(__dir__, 'clickhouse_backup', '*.rb')].sort.each do |f|
  require f
end

Dir[File.join(__dir__, 'clickhouse_patches', '*.rb')].sort.each do |f|
  require f
end

# Base module of application
module ClickhouseBackup
  # Class methods
  module ClassMethods
    REQUIRED_METHODS = %i[
      database
      name
      data_paths
      metadata_path
    ].freeze

    attr_accessor :root

    def configuration
      @___configuration
    end

    def make_backup
      no_need_for_backup unless backup_needed?

      show_clickhouse_incompatible unless clickhouse_compatible?

      cleanup

      write_archive

      # upload_to_s3(archive_name)

      cleanup
    end

    def cleanup_file(archive_name)
      FileUtils.remove_entry_secure(archive_name)
    rescue StandardError => e
      logger.error { e.message }
    end

    def upload_to_s3(archive_name)
      u = ClickhouseBackup::S3Uploader.new(archive_name)
      u.upload
    end

    def cleanup
      path = File.join(shadow_path, '*')
      logger.info { "Removing friezed data from #{path}" }
      Dir[path].each do |f|
        logger.debug { "Removing file: #{f}" }
        FileUtils.remove_entry_secure(f)
      rescue StandardError => e
        logger.error { e.message }
      end
    end

    def write_archive
      p1, p2, p3 = nil, nil, nil
      IO.pipe do |archive_stream_reader, archive_stream_writer|
        IO.pipe do |in_names, out_names|
          p1 = fork do
            STDERR.puts "Reader process running"
            archive_stream_writer.close
            in_names.close

            write_chunked_file(archive_stream_reader, out_names)

            archive_stream_reader.close
            
            out_names.flush
            out_names.close

            STDERR.puts "Reader process finished"
          end

          p2 = fork do
            STDERR.puts "Uploader process running"
            out_names.close

            upload_part(in_names)

            in_names.close
            STDERR.puts "Uploader process finished"
          end
        end

        p3 = fork do
          STDERR.puts "Writer process running"
          archive_stream_reader.close

          make_archive_stream(archive_stream_writer)

          archive_stream_writer.flush
          archive_stream_writer.close

          STDERR.puts "Writer process finished"
        end
      end

      Process.wait(p1)
      Process.wait(p2)
      Process.wait(p3)
    end

    def make_archive_stream(wr)
      tar_writer = ClickhouseBackup::TarWriter.new(wr)

      archive_maker = ClickhouseBackup::ArchiveMaker.new(tar_writer)
      archive_maker.make_archive(find_shadow_files, find_schema_files)

      restore_writer = ClickhouseBackup::RestoreScriptBuilder.new(tar_writer)
      restore_writer.write_restore_scripts(table_descriptions)

      tar_writer.close
    end

    def write_chunked_file(rd, maked_archives)
      max_blocks_to_read = 1024 # Part size 10GB
      block_1mb = 1024*1024

      current_chunk = 0
      current_read_block = 0

      read_next = true
      current_archive_name = "--"

      while read_next
        current_file = if current_read_block >= max_blocks_to_read || current_chunk.zero?
                         if current_file
                           current_file.flush
                           current_file.close
                           maked_archives << current_archive_name
                           maked_archives << '\n'
                         end
                         current_chunk += 1
                         current_read_block = 0
                         current_archive_name = format(archive_name, current_chunk)
                         File.open(current_archive_name, 'wb')
                       else
                         current_file
                       end

        if rd.eof?
          logger.info { "TAR stream EOF reached" }
          read_next = false
          current_file.flush
          current_file.close
          maked_archives << current_archive_name
          maked_archives << '\n'
        else
          current_file << rd.read(block_1mb)
          current_read_block += 1
        end
      end
    end

    
    def upload_part(out_names)
      while !out_names.eof?
        next_name = out_names.gets

        if (next_name)
          STDERR.puts next_name
          upload_to_s3(current_archive_name.strip)
          cleanup_file(current_archive_name.strip)
        end
      end
    end

    def shadow_path
      File.expand_path(configuration['clickhouse']['shadow'])
    end

    def read_configuration(configuration_file_path)
      @___configuration = YAML.safe_load(File.open(configuration_file_path))

      ClickHouse.config.assign(configuration['clickhouse']['connection'].merge(logger: logger))
    end

    def ignored_databases
      ClickhouseBackup.configuration['ignored_databases']
    end

    private

    def no_need_for_backup
      logger.info 'No tables with data found. Skipping backup.'
      exit(0)
    end

    def show_clickhouse_incompatible
      logger.error "Not compatible Clickhouse version. Please update it or open ticket to support your version.\n"
      logger.error "Additional info:\n"
      logger.error "Table description fields: #{ClickhouseBackup::Models::TableDescription.fields.map(&:to_s)}"
      exit(0)
    end

    def backup_needed?
      !table_descriptions.empty?
    end

    def clickhouse_compatible?
      first_description = table_descriptions.first

      REQUIRED_METHODS.each do |m|
        return false unless first_description.respond_to?(m)
      end

      true
    end

    def ignored_shadow_file?(file)
      ignored_databases.any? { |y| file.to_s.start_with?(File.join(shadow_path, y)) }
    end

    def find_shadow_files
      freeze_data
      logger.info { "Looking for shadow files at: #{shadow_path}" }
      files = Dir[File.join(shadow_path, '**', '*')]
              .reject { |x| ignored_shadow_file?(x) }
      logger.debug { "Found shadow files: #{files.count}." }
      files
    end

    def find_schema_files
      table_descriptions.map(&:metadata_path)
    end

    def freeze_data
      logger.info { 'Freezing data tables...' }
      table_descriptions.each do |td|
        logger.debug { "Freezing table: #{td.database}.#{td.name}" }
        td.freeze
      end
      logger.debug { 'Freezing data tables completed.' }
    end

    def table_descriptions
      return @___table_descriptions if @___table_descriptions

      logger.info { 'Retrieving tables description...' }
      @___table_descriptions = ClickhouseBackup::Models::TableDescription.all.to_a
      logger.debug { 'Tables description retrieved.' }
      logger.debug { "Tables for backup: #{@___table_descriptions.count} ." }
      @___table_descriptions
    end

    def archive_name
      return @__archive_path if @__archive_path

      @__archive_path = File.expand_path(File.join(archive_location, tar_file_name))
      logger.debug { "Archive will be located at: #{@__archive_path}" }
      @__archive_path
    end

    def tar_file_name
      archive_idx = Time.now.strftime('%Y%m%d%H%M%S')
      archive_prefix = ClickhouseBackup.configuration['backup']['archive-prefix'] || ''
      "#{archive_prefix}#{archive_idx}.%05d.tar"
    end

    def archive_location
      archive_location = ClickhouseBackup.configuration['backup']['temp-file-location'] || '~'
      archive_location = archive_location.gsub(%r{\/$}, '')
      FileUtils.mkdir_p(archive_location)
      archive_location
    end
  end

  extend ClickhouseBackup::Logger
  extend ClassMethods
end
