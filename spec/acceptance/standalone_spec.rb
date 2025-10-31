require 'spec_helper_acceptance'

describe 'standalone' do
  let(:manage_firewall) { "(getvar('facts.os.family') == 'RedHat' and Integer(getvar('facts.os.release.major')) > 7)" }
  let(:postgres_version) { 'undef' } # default
  let(:puppetdb_master_config_params) {}
  let(:puppetdb_params) {}

  it_behaves_like 'puppetserver'

  describe 'with defaults' do
    it_behaves_like 'puppetdb'

    describe service('puppetdb'), :status do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe port(8080), :status do
      it { is_expected.to be_listening }
    end

    describe port(8081), :status do
      it { is_expected.to be_listening }
    end

    context 'puppetdb postgres user', :status do
      it 'is not allowing read-only user to create tables' do
        command('psql "postgresql://puppetdb-read:puppetdb-read@localhost/puppetdb" -c "create table tables(id int)"') do
          its(:stderr) { is_expected.to match %r{^ERROR:  permission denied for schema public.*} }
          its(:exit_status) { is_expected.to eq 1 }
        end
      end

      it 'is allowing normal user to manage schema' do
        command('psql "postgresql://puppetdb:puppetdb@localhost/puppetdb" -c "create table testing(id int); drop table testing"') do
          its(:exit_status) { is_expected.to eq 0 }
        end
      end

      it 'is allowing read-only user to select' do
        command('psql "postgresql://puppetdb-read:puppetdb-read@localhost/puppetdb" -c "select * from catalogs limit 1"') do
          its(:exit_status) { is_expected.to eq 0 }
        end
      end
    end
  end

  context 'with manage report processor', :change do
    %w[remove add].each do |outcome|
      context "#{outcome}s puppet config puppetdb report processor" do
        let(:enable_reports) { outcome == 'add' }

        let(:puppetdb_master_config_params) do
          <<~EOS
            manage_report_processor => true,
            enable_reports          => #{enable_reports},
          EOS
        end

        it_behaves_like 'puppetdb'

        describe command('puppet config print --section master reports') do
          its(:stdout) do
            option = enable_reports ? 'to' : 'not_to'
            is_expected.method(option).call match 'puppetdb'
          end
        end
      end
    end
  end

  describe 'puppetdb with postgresql ssl', :change do
    let(:puppetdb_params) do
      <<~EOS
        postgresql_ssl_on       => true,
        database_listen_address => '0.0.0.0',
        database_host           => $facts['networking']['fqdn'],
      EOS
    end

    it_behaves_like 'puppetdb'
  end

  describe 'set wrong database password in puppetdb conf', :change do
    it 'applies manifest' do
      pp = <<~EOS
        ini_setting { "puppetdb password":
          ensure  => present,
          path    => '/etc/puppetlabs/puppetdb/conf.d/database.ini',
          section => 'database',
          setting => 'password',
          value   => 'random_password',
        }
        ~> service { 'puppetdb':
          ensure => 'running',
        }
      EOS

      apply_manifest(pp, expect_failures: false, debug: ENV.key?('DEBUG'))
    end

    describe service('puppetdb') do
      it { is_expected.to be_running }
    end
  end

  describe 'supports changing database port', :change do
    let(:puppetdb_params) do
      <<~EOS
        database_port           => '5433',
        read_database_port      => '5433',
      EOS
    end

    it_behaves_like 'puppetdb'

    describe port(5433), :status do
      it { is_expected.to be_listening }
    end

    describe service('puppetdb') do
      it { is_expected.to be_running }
    end
  end
end
