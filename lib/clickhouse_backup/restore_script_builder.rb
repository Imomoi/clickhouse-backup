# frozen_string_literal: true

require 'erb'

module ClickhouseBackup
  # Parameters for restore scripts
  class TemplateParams
    attr_reader :db_name
    attr_reader :templates

    def initialize(db_name, templates)
      @db_name = db_name
      @templates = templates
    end

    def binding
      super
    end
  end

  # Module for making real backup archive
  class RestoreScriptBuilder
    attr_reader :tar_writer, :templates

    FILE_EXTENSION = '.sh.erb'

    def initialize(tar_writer)
      @tar_writer = tar_writer
      @templates = {}

      prerender_templates
    end

    def write_restore_scripts(table_descriptions)
      write_full_restore
      write_db_restore_scripts(table_descriptions)
      write_table_restore_scripts(table_descriptions)
    end

    private

    def write_full_restore
      script_template = templates['all']
      template_data = TemplateParams.new(nil, templates)
      rendered_template = ERB.new(script_template, 0, '-%<>').result(template_data.binding)
      tar_writer.write_data('restore.sh', rendered_template)
    end

    def write_db_restore_scripts(table_descriptions)
      table_descriptions.collect(&:database).uniq.each do |db|
        script_template = templates['db']
        template_data = TemplateParams.new(db, templates)
        rendered_template = ERB.new(script_template, 0, '-%<>').result(template_data.binding)
        tar_writer.write_data("#{db}/restore.sh", rendered_template)
      end
    end

    def write_table_restore_scripts(table_descriptions)
      table_descriptions.each do |t|
        template_data = TemplateParams.new(t.database, templates)
        script_template = templates['table']
        rendered_template = ERB.new(script_template, 0, '-%<>').result(template_data.binding)
        tar_writer.write_data("#{t.database}/#{t.name}/restore.sh", rendered_template)
      end
    end

    def prerender_templates
      read_templates
    end

    def read_templates
      Dir[File.join(__FILE__.gsub(/\.rb$/, ''), "*#{FILE_EXTENSION}")].each do |f|
        templates[File.basename(f, FILE_EXTENSION)] = File.read(f)
      end
    end
  end
end
