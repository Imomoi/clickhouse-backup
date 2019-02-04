# frozen_string_literal: true

require 'rubygems/package'

module ClickhouseBackup
  # Class for writing tar files
  class TarWriter
    BLOCKSIZE_TO_READ = 1024 * 1024

    attr_accessor :tar, :archive_file

    def initialize(archive_name)
      self.archive_file = File.open archive_name, 'wb'
      self.tar = Gem::Package::TarWriter.new archive_file
    end

    def package_file
      yield(self)
    end

    def process_files(files, base_path, prefix)
      files.each do |f|
        process_file(f, base_path, prefix)
      end
    end

    def write_data(path, data)
      tar.add_file_simple path, 0x777, data.length do |tio|
        tio.write data
      end
    end

    def close
      tar.flush
      tar.close
      archive_file.flush
      archive_file.close
    end

    private

    def logger
      ClickhouseBackup.logger
    end

    def process_file(file, base_path, prefix)
      logger.debug { "Packing: #{file}" }

      relative_path = file.sub "#{base_path}/", prefix
      mode = File.stat(file).mode
      size = File.stat(file).size
      make_directory_or_store_file(file, relative_path, mode, size)
    end

    def make_directory_or_store_file(file, relative_path, mode, size)
      aligned_path = align_data_path(relative_path)

      return unless aligned_path

      if File.directory? file
        tar.mkdir aligned_path, mode
      else
        store_file(file, aligned_path, mode, size)
      end
    end

    def store_file(file, relative_path, mode, size)
      tar.add_file_simple relative_path, mode, size do |tio|
        File.open file, 'rb' do |rio|
          while (buffer = rio.read(BLOCKSIZE_TO_READ))
            tio.write buffer
          end
        end
      end
    end

    # Aligns data paths for clickhouse backups to follow next structure
    # DB/TABLE/PARTITION/DATAFILE
    def align_data_path(relative_path)
      reqex = %r{/\d+/data/(.*)$}
      aligned_data_path = reqex.match(relative_path)
      unless aligned_data_path
        reqex2 = %r{metadata/(.*)$}
        aligned_data_path = reqex2.match(relative_path)

        return nil unless aligned_data_path
      end

      return nil if aligned_data_path[1].length <= 1
      return aligned_data_path[1] unless aligned_data_path[1].end_with?('/')

      aligned_data_path[1][0..-2]
    end
  end
end
