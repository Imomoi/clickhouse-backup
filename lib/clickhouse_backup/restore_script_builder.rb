# frozen_string_literal: true

require 'erb'

module ClickhouseBackup
  # Module for making real backup archive
  class RestoreScriptBuilder
    attr_reader :tar_writer, :templates, :rendered_templates

    FILE_EXTENSION = '.sh.erb'

    def initialize(tar_writer)
      @tar_writer = tar_writer
      @rendered_templates = {}
      @templates = {}

      prerender_templates
    end

    def write_restore_scripts(table_descriptions)
      tar_writer.write_data('restore.sh', rendered_templates['all'])

      write_db_restore_scripts(table_descriptions)
      write_table_restore_scripts(table_descriptions)
    end

    private

    def write_db_restore_scripts(table_descriptions)
      table_descriptions.collect(&:database).uniq.each do |db|
        script_template = templates[File.basename(f, FILE_EXTENSION)] = File.read(f)
        template_data = OpenStruct.new
        template_data.db_name = db
        template_data.rendered_templates = templates
        ERB.new(script_template, 0, '-%<>').result(binding)
        tar_writer.write_data("#{db}/restore.sh", rendered_templates['db'])
      end
    end

    def write_table_restore_scripts(table_descriptions)
      table_descriptions.each do |t|
        tar_writer.write_data("#{t.database}/#{t.name}/restore.sh", rendered_templates['table'])
      end
    end

    def prerender_templates
      read_templates

      templates.reject { |k, _| k.start_with?('_') }.each do |k, t|
        rendered_templates[k] = ERB.new(t, 0, '-%<>').result(binding)
      end
    end

    def read_templates
      Dir[File.join(__FILE__.gsub(/\.rb$/, ''), "*#{FILE_EXTENSION}")].each do |f|
        templates[File.basename(f, FILE_EXTENSION)] = File.read(f)
      end
    end
  end
end
