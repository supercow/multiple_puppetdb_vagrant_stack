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
  $pdb1_ip = regsubst($pdb1,'^([0-9.]*).*$','\1')
  $pdb2 = generate('/bin/getent', 'hosts', 'pdb2.vm')
  $pdb2_ip = regsubst($pdb2,'^([0-9.]*).*$','\1')

  haproxy::balancermember { 'puppetdb-pdb1.vm':
    server_names      => 'pdb1.vm',
    ipaddresses       => $pdb1_ip,
    ports             => '8081',
    listening_service => 'puppetdb',
  }
  haproxy::balancermember { 'puppetdb-pdb2.vm':
    server_names      => 'puppetdb2.vm',
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
}

node /^pdb\d\.vm/ {
  class { 'puppet_enterprise::profile::puppetdb':
    certname              => 'haproxy.vm',
    database_name         => 'mom.vm',
  }

  class { '::puppetdb_shared_cert::puppetdb':
    certname => 'haproxy.vm',
    before   => Puppet_enterprise::Certs['pe-puppetdb'],
  }
}

node 'mom.vm' {
  class { '::puppetdb_shared_cert::ca':
    certname      => 'haproxy.vm',
    dns_alt_names => ['haproxy','puppetdb','puppetdb.vm'],
  }
}


