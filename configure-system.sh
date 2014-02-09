# We assume that we already have a Docker-compatible kernel and appropriate
# grub options set up.  (See our precise64-docker subdirectory for a script
# which does this under Docker.)  Everything after that is up to this script.
#
# This script will be run repeatedly, so it should be "idempotent", in the
# devops sense of doing nothing if run a second time in the same
# environment.  This script may run either under Vagrant, or manually
# against a Linode server (which can't be provisioned via Vagrant at the
# time of writing).

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
echo 'deb http://get.docker.io/ubuntu docker main' > /etc/apt/sources.list.d/docker.list

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y lxc-docker
