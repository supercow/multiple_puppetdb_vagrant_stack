# Sandbox environment for multiple PuppetDB Servers

This Vagrant environment is a fork of puppet-debugging-kit that automatically
creates a Puppet infrastructure with:

- A MoM with a PostgreSQL database
- Two PuppetDB servers behind an HAProxy load balancer

A shared certificate is generated and shared amongst the PuppetDB servers to
avoid issues related to [SERVER-207](https://tickets.puppetlabs.com/browse/SERVER-207).

This environment is created as an example of how to configure multiple PuppetDB
instances when load needs to be distributed. It should be used as a reference,
and not copied completely in a production deployment.

## Using this environment

1. `bundle install`
1. `bundle exec vagrant up`
1. Change `puppetdb_host` in the `PE Infrastructure` group to `puppetdb.vm`
1. Run `puppet agent -t` on the `mom.vm`
