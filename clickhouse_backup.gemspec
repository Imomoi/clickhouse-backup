# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'bundler/version'

Gem::Specification.new do |spec|
  spec.name = 'ClickhouseBackup'
  spec.version = '1.0.0'
  spec.platform = Gem::Platform::RUBY
  spec.date = '2019-02-04'
  spec.summary = 'Backup and restore tools for Clickhouse DB'
  spec.authors = ['Viacheslav Molokov']
  spec.email = 'viacheslav.molokov@gmail.com'
  spec.files = Dir.glob('{bin,lib}/**/*')
  spec.executables  = ['clickhouse_backup']
  spec.require_path = 'lib'

  spec.add_runtime_dependency 'aws-sdk-s3', '1.82.0'
  spec.add_runtime_dependency 'clickhouse', '0.1.10'
end
