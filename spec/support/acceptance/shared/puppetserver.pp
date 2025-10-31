# some provision environments (docker) may not setup or isolate domains
# this ensures the instance FQDN is always resolved locally
host { 'primary':
  name         => $facts['networking']['fqdn'],
  ip           => $facts['networking']['ip'],
  host_aliases => [
    $facts['networking']['hostname'],
  ],
}

if $facts['os']['family'] == 'RedHat' {
  # TODO: backport to litmusimage, required for serverspec port tests
  package { 'iproute': ensure => installed }

  # TODO: rework this hack, maybe not needed for newer version of postgresl module?
  if versioncmp($facts['os']['release']['major'], '8') >= 0 {
    package { 'disable-builtin-dnf-postgresql-module':
      ensure   => 'disabled',
      name     => 'postgresql',
      provider => 'dnfmodule',
    }

    Yumrepo <| tag == 'postgresql::repo' |>
    -> Package['disable-dnf-postgresql-module']
    -> Package <| tag == 'postgresql' |>
  }

  # Work-around EL systemd in docker with cgroupsv1? issue and forked services
  # Without this, the puppet agent will stall for 300 seconds waiting for
  # the service to start... then miserably fail.
  # systemd error message:
  #     New main PID 1411 does not belong to service, and PID file is not
  #     owned by root. Refusing.
  # PIDFile is not needed, but it cannot be reset by a drop-in, therefor the
  # original unit must be modified
  file_line { 'puppetserver-unit-remove-pidfile':
    path               => '/lib/systemd/system/puppetserver.service',
    line               => '#PIDFile=/run/puppetlabs/puppetserver.pid',
    match              => '^PIDFile.*',
    append_on_no_match => false,
    require            => Package['openvox-server'],
    notify             => Service['puppetserver'],
  }
}

$sysconfdir = $facts['os']['family'] ? {
  'Debian' => '/etc/default',
  default  => '/etc/sysconfig',
}

case fact('os.family') {
  'Archlinux': {
    $puppetserver_package = 'puppetserver'
  }
  'Debian', 'RedHat', 'Suse': {
    $puppetserver_package = 'openvox-server'
  }
  default: {
    fail("The fact 'os.family' is set to ${fact('os.family')} which is not supported by the puppetdb module.")
  }
}

package { $puppetserver_package:
  ensure => installed,
}
# savagely disable dropsonde
~> file {
  [
    '/opt/puppetlabs/server/data/puppetserver/dropsonde/bin/dropsonde',
    '/opt/puppetlabs/server/apps/puppetserver/cli/apps/dropsonde',
  ]:
    ensure => absent,
}
-> exec { '/opt/puppetlabs/bin/puppetserver ca setup':
  creates => '/etc/puppetlabs/puppetserver/ca/ca_crt.pem',
}
# drop memory requirements to fit on a low memory containers
-> augeas { 'puppetserver-environment':
  context => "/files${sysconfdir}/puppetserver",
  changes => [
    'set JAVA_ARGS \'"-Xms512m -Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger"\'',
  ],
}
-> service { 'puppetserver':
  ensure => running,
  enable => true,
}
