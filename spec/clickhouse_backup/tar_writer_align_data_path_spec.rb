# frozen_string_literal: true

describe ClickhouseBackup::TarWriter, '.align_data_path' do
  context '.align_data_path for directory (db)' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data/db' }
    it { is_expected.to eql('db') }
  end

  context 'for directory (db/table)' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data/db/table' }
    it { is_expected.to eql('db/table') }
  end

  context 'for directory (db/table/partition) with leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data/db/table/partition/' }
    it { is_expected.to eql('db/table/partition') }
  end

  context 'for directory (db/table/partition) without leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data/db/table/partition' }
    it { is_expected.to eql('db/table/partition') }
  end

  context 'for file' do
    subject do
      described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data/db/table/partition/data.dat'
    end
    it { is_expected.to eql('db/table/partition/data.dat') }
  end
end

describe ClickhouseBackup::TarWriter, '.align_data_path' do
  context 'for metadata directory without leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, 'metadata/db' }
    it { is_expected.to eql('db') }
  end

  context 'for metadata directory with leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, 'metadata/db' }
    it { is_expected.to eql('db') }
  end

  context 'for metadata sql file' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, 'metadata/db/table.sql' }
    it { is_expected.to eql('db/table.sql') }
  end

  context 'for metadata directory without leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1/data' }
    it { is_expected.to eql(nil) }
  end

  context 'for metadata directory without leading backslash' do
    subject { described_class.new(Tempfile.new.path).send :align_data_path, '/shadows_path/1' }
    it { is_expected.to eql(nil) }
  end
end
