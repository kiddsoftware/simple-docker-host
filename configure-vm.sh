#!/bin/bash -e

# This makes it easier to call docker commands, which has the side-effect
# of making the vagrant user root-equivalent.  But we were already, so no
# problem.
usermod -a -G docker vagrant

# Install a few more packages we don't need in production.
export DEBIAN_FRONTEND=noninteractive
apt-get install -y avahi-daemon

echo "Successfully provisioned VM extras!"
