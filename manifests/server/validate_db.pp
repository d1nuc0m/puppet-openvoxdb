# @summary validates the database connection
#
# @api private
class openvoxdb::server::validate_db (
  $database_host       = $openvoxdb::params::database_host,
  $database_port       = $openvoxdb::params::database_port,
  $database_username   = $openvoxdb::params::database_username,
  Variant[String[1], Sensitive[String[1]]] $database_password = $openvoxdb::params::database_password,
  $database_name       = $openvoxdb::params::database_name,
  $jdbc_ssl_properties = $openvoxdb::params::jdbc_ssl_properties,
) inherits openvoxdb::params {
  if ($database_password != undef and $jdbc_ssl_properties == false) {
    postgresql_conn_validator { 'validate puppetdb postgres connection':
      host        => $database_host,
      port        => $database_port,
      db_username => $database_username,
      db_password => $database_password,
      db_name     => $database_name,
    }
  }
}
