require 'spec_helper'

describe 'openvoxdb::server::global', type: :class do
  let(:facts) { on_supported_os.take(1).first[1] }

  describe 'when using default values' do
    it {
      is_expected.to contain_ini_setting('puppetdb_global_vardir')
        .with(
          'ensure' => 'present',
          'path' => '/etc/puppetlabs/puppetdb/conf.d/config.ini',
          'section' => 'global',
          'setting' => 'vardir',
          'value' => '/opt/puppetlabs/server/data/puppetdb',
        )
    }

    it {
      is_expected.to contain_file('/etc/puppetlabs/puppetdb/conf.d/config.ini')
        .with(
          'ensure' => 'file',
          'owner' => 'root',
          'group' => 'puppetdb',
          'mode' => '0640',
        )
    }
  end
end
