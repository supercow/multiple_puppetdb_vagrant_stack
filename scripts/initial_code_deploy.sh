#!/bin/bash

cp /vagrant/r10k.yaml /etc/puppetlabs/r10k/r10k.yaml
/opt/puppetlabs/bin/r10k deploy environment production -pv
