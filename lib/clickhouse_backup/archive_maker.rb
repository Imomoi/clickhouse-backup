# frozen_string_literal: true

module ClickhouseBackup
  # Module for making real backup archive
  class ArchiveMaker
    # Class methods for module
    attr_accessor :shadow_files, :schema_files

    attr_reader :tar_writer

    def initialize(tar_writer)
      @tar_writer = tar_writer
    end

    def logger
      ClickhouseBackup.logger
    end

    def shadow_path
      ClickhouseBackup.shadow_path
    end

    def make_archive(shadow_files = [], schema_files = [])
      self.shadow_files = shadow_files
      self.schema_files = schema_files
      show_total_file_to_process
      show_total_file_size

      tar_writer.package_file do |tar|
        tar.process_files(shadow_files, shadow_path, 'shadow/')
        tar.process_files(schema_files, align_metadata_path(schema_files), 'metadata/')
      end
    end

    private

    def show_total_file_to_process
      logger.info { "Total files to process: #{shadow_files.count + schema_files.count}" }
    end

    def show_total_file_size
      total_file_size = (shadow_files + schema_files)
                        .select { |x| File.file?(x) }
                        .map { |x| File.size(x) }
                        .inject(0) { |sum, x| sum + x } / 1024 / 1024

      logger.info { "Total files size: #{total_file_size} MiB." }
    end

    def align_metadata_path(schema_files)
      metadata_config = ClickhouseBackup.configuration['clickhouse']['metadata']
      metadata_path, metadata_docker_volume = File.expand_path(metadata_config).split(':')
      return metadata_path unless metadata_docker_volume

      schema_files.each do |sf|
        sf.gsub!(metadata_path, metadata_docker_volume)
      end

      metadata_docker_volume
    end
  end
end
