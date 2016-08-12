# ensure puppetdb.vm is resolvable to everyone
# This is a hack. Don't do this on a real machine
$haproxy = generate('/bin/getent', 'hosts', 'haproxy.vm')
$haproxy_ip = strip(regsubst($haproxy,'^([0-9.]*).*$','\1'))
host { 'puppet.vm':
  ensure       => 'present',
  ip           => $haproxy_ip,
  host_aliases => ['puppet'],
}
host { 'puppetdb.vm':
  ensure       => 'present',
  ip           => $haproxy_ip,
  host_aliases => ['puppetdb'],
}

node default {}

node 'haproxy.vm' {
  class { '::haproxy':
    global_options => {
      'log'     => "${::ipaddress} local0",
      'chroot'  => '/var/lib/haproxy',
      'pidfile' => '/var/run/haproxy.pid',
      'maxconn' => '4000',
      'daemon'  => '',
      'stats'   => 'socket /var/lib/haproxy/stats',
    },
  }

  Haproxy::Balancermember {
    options => 'check',
  }

  Haproxy::Listen {
    ipaddress        => '*',
    mode             => 'tcp',
    collect_exported => false,
    options          => {
      'option' => [ 'tcplog' ],
    }
  }

  haproxy::listen { 'stats':
    ports   => '9090',
    mode    => 'http',
    options => {
      'stats' => ['uri /', 'auth puppet:puppet', 'refresh 3s']
      },
  }

  # PuppetDB active/active leastconn

  # figure out the PDB IP addresses
  # change these lines on a real system, will only work with hosts files
  $pdb1 = generate('/bin/getent', 'hosts', 'pdb1.vm')
  $pdb1_ip = strip(regsubst($pdb1,'^([0-9.]*).*$','\1'))
  $pdb2 = generate('/bin/getent', 'hosts', 'pdb2.vm')
  $pdb2_ip = strip(regsubst($pdb2,'^([0-9.]*).*$','\1'))
  $mom = generate('/bin/getent', 'hosts', 'mom.vm')
  $mom_ip = strip(regsubst($mom,'^([0-9.]*).*$','\1'))

  haproxy::balancermember { 'puppetdb-pdb1.vm':
    server_names      => 'pdb1.vm',
    ipaddresses       => $pdb1_ip,
    ports             => '8081',
    listening_service => 'puppetdb',
  }
  haproxy::balancermember { 'puppetdb-pdb2.vm':
    server_names      => 'pdb2.vm',
    ipaddresses       => $pdb2_ip,
    ports             => '8081',
    listening_service => 'puppetdb',
  }
  haproxy::listen { 'puppetdb':
    ports   => '8081',
    options => {
      'balance' => 'leastconn',
    },
  }

  # Compile master pool
  $compile1 = generate('/bin/getent', 'hosts', 'compile1.vm')
  $compile1_ip = strip(regsubst($compile1,'^([0-9.]*).*$','\1'))
  haproxy::balancermember { 'compile-compile1.vm':
    server_names      => 'compile1.vm',
    ipaddresses       => $compile1_ip,
    ports             => '8081',
    listening_service => 'puppet',
  }
  haproxy::listen { 'puppet':
    ports   => '8140',
    options => {
      'balance' => 'leastconn',
    },
  }

}

node /^pdb\d\.vm/ {

  user { 'pe-puppet':
    ensure => present,
    gid    => 'pe-puppetdb',
  }
  # Use a shared cert due to SERVER-207
  class { '::puppetdb_shared_cert::puppetdb':
    certname => 'pe-puppetdb',
    before   => Puppet_enterprise::Certs['pe-puppetdb'],
  }

  # Install PuppetDB
  #class { 'puppet_enterprise::profile::puppetdb':
  #  certname              => 'puppetdb.vm',
  #  database_name         => 'mom.vm',
  #}

}

node 'mom.vm' {
  package { 'puppetclassify':
    ensure   => present,
    provider => 'puppet_gem',
  }

  # Generate the shared cert for PuppetDB
  node_group { 'Standalone PuppetDB':
    parent  => 'PE Infrastructure',
    rule    => ['and', ['~',['fact','fqdn'],'^pdb\d+\.vm$']],
    classes => {'puppet_enterprise::profile::puppetdb' => { 'certname' => 'pe-puppetdb' } },
  }

  node_group { 'Standalone Compile Master':
    parent  => 'PE Infrastructure',
    rule    => ['and', ['~',['fact','fqdn'],'^compile\d+\.vm$']],
    classes => {'puppet_enterprise::profile::master' => { 'puppetdb_host' => 'puppetdb.vm' } },
  }

  class { '::puppetdb_shared_cert::ca':
    certname      => 'pe-puppetdb',
    dns_alt_names => ['haproxy','haproxy.vm','puppetdb', 'puppetdb.vm'],
  }

  # Ideally, this would be done through hieradata, but we don't apply the database profile...
  file_line { 'pe-puppetdb ident mapping':
    path => '/opt/puppetlabs/server/data/postgresql/9.4/data/pg_ident.conf',
    line => 'pe-puppetdb-map pe-puppetdb pe-puppetdb',
  }
}


