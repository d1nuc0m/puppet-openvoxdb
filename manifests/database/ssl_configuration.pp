# @summary configure SSL for the PuppetDB postgresql database
#
# @api private
class openvoxdb::database::ssl_configuration (
  $database_name               = $openvoxdb::params::database_name,
  $database_username           = $openvoxdb::params::database_username,
  $read_database_username      = $openvoxdb::params::read_database_username,
  $read_database_host          = $openvoxdb::params::read_database_host,
  $puppetdb_server             = $openvoxdb::params::puppetdb_server,
  $postgresql_ssl_key_path     = $openvoxdb::params::postgresql_ssl_key_path,
  $postgresql_ssl_cert_path    = $openvoxdb::params::postgresql_ssl_cert_path,
  $postgresql_ssl_ca_cert_path = $openvoxdb::params::postgresql_ssl_ca_cert_path,
  $postgres_version            = $openvoxdb::params::postgres_version,
  $create_read_user_rule       = false,
) inherits openvoxdb::params {
  File {
    ensure  => present,
    owner   => 'postgres',
    mode    => '0600',
    require => Package['postgresql-server'],
  }

  file { 'postgres private key':
    path   => "${postgresql::server::datadir}/server.key",
    source => $postgresql_ssl_key_path,
  }

  file { 'postgres public key':
    path   => "${postgresql::server::datadir}/server.crt",
    source => $postgresql_ssl_cert_path,
  }

  postgresql::server::config_entry { 'ssl':
    ensure  => present,
    value   => 'on',
    require => [File['postgres private key'], File['postgres public key']],
  }

  postgresql::server::config_entry { 'ssl_cert_file':
    ensure  => present,
    value   => "${postgresql::server::datadir}/server.crt",
    require => [File['postgres private key'], File['postgres public key']],
  }

  postgresql::server::config_entry { 'ssl_key_file':
    ensure  => present,
    value   => "${postgresql::server::datadir}/server.key",
    require => [File['postgres private key'], File['postgres public key']],
  }

  postgresql::server::config_entry { 'ssl_ca_file':
    ensure  => present,
    value   => $postgresql_ssl_ca_cert_path,
    require => [File['postgres private key'], File['postgres public key']],
  }

  openvoxdb::database::postgresql_ssl_rules { "Configure postgresql ssl rules for ${database_username}":
    database_name     => $database_name,
    database_username => $database_username,
    postgres_version  => $postgres_version,
    puppetdb_server   => $puppetdb_server,
  }

  if $create_read_user_rule {
    openvoxdb::database::postgresql_ssl_rules { "Configure postgresql ssl rules for ${read_database_username}":
      database_name     => $database_name,
      database_username => $read_database_username,
      postgres_version  => $postgres_version,
      puppetdb_server   => $puppetdb_server,
    }
  }
}
