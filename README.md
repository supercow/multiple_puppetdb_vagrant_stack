# Sandbox environment for multiple PuppetDB Servers

This Vagrant environment is a fork of puppet-debugging-kit that automatically
creates a Puppet infrastructure with:

- A MoM with a PostgreSQL database
- Two PuppetDB servers behind an HAProxy load balancer
- One separate compile master using the load balanced PuppetDB VIP

A shared certificate is generated and shared amongst the PuppetDB servers to
avoid issues related to [SERVER-207](https://tickets.puppetlabs.com/browse/SERVER-207).

This environment is created as an example of how to configure multiple PuppetDB
instances when load needs to be distributed. It should be used as a reference,
and not copied completely in a production deployment.

## Using this environment

1. `bundle install`
1. `bundle exec vagrant up`
1. Run `puppet agent -t` on the `mom.vm`
1. Sign the compile master cert with `--allow-dns-alt-names` on the MoM
1. Run `puppet agent -t` on each server
1. Add puppet.vm to the agent's host file and run `puppet agent -t`. Verify from
   the PuppetDB logs that one of the load balanced PuppetDB servers is receiving
   the commands instead of the MoM.
