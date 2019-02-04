# frozen_string_literal: true

require 'aws-sdk-s3'

module ClickhouseBackup
  # Uploader to Amazon S3
  class S3Uploader
    CONFIG_EXAMPLE = <<~DEST
      To use AWS S3 as your destination add folowing configartion:

      destinations:
        s3:
          bucket: 'YOUR_BUCKET'
          key: 'AMI_USER_KEY'
          secret: 'AMI_USER_SECRET'
          region: 'REGION'
    DEST

    attr_reader :s3conf
    attr_reader :file

    def initialize(file)
      @file = file

      destinations = ClickhouseBackup.configuration['destinations']
      unless destinations
        logger.warn 'No destinations found in your configuration.'
        logger.warn CONFIG_EXAMPLE
        return
      end

      @s3conf = destinations['s3']
      logger.warn CONFIG_EXAMPLE unless s3conf
    end

    def upload
      return unless s3conf

      print_upload_info

      s3_client.bucket(s3_bucket).object(file_object_key).upload_file(file, tagging: tags)
    end

    private

    def tags
      t = {}
      d = DateTime.now
      t['archive_type'] = if d.mday == 1
                            'monthly'
                          elsif d.wday == 1
                            'weekly'
                          else
                            'daily'
                          end

      hash_to_query_string(t)
    end

    def hash_to_query_string(hash)
      hash.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join('&')
    end

    def file_object_key
      File.basename(file)
    end

    def logger
      ClickhouseBackup.logger
    end

    def print_upload_info
      logger.info { "Uploading #{file_object_key} to AWS S3: bucket: #{s3_bucket}, access key: #{s3_key}" }
      logger.debug { "Source file: #{file}" }
    end

    def s3_bucket
      s3conf['bucket']
    end

    def s3_key
      s3conf['key']
    end

    def s3_client
      Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(s3_key, s3conf['secret']),
        region: s3conf['region']
      )
    end
  end
end
