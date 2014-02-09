#!/bin/bash -e

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

# Install docker and some other things we'll need.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y lxc-docker git

# Configure docker to not restart running containers on boot, since it's
# unreliable at the best of times, and we want to use upstart.
sed -i 's/.*DOCKER_OPTS=.*/DOCKER_OPTS=\"-r=false\"/g' /etc/default/docker
service docker restart
sleep 2 # Docker sometimes starts a little slowly.

# Install a private registry, if we don't already have one.
# Based on Dockerfile from https://github.com/dotcloud/docker-registry
cd /root
if [ ! -d docker-registry ]; then 
  git clone https://github.com/dotcloud/docker-registry.git
fi
cd docker-registry
git reset --hard
git pull
cat <<EOF > config.yml
dev:
    loglevel: info
    storage: local
    storage_path: /data/registry
EOF
cat <<EOF > Dockerfile
FROM ubuntu:12.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y git-core build-essential python-dev \
       libevent1-dev python-openssl liblzma-dev wget && \
    rm /var/lib/apt/lists/*_*
RUN cd /tmp && wget http://python-distribute.org/distribute_setup.py
RUN cd /tmp && python distribute_setup.py; easy_install pip && \
    rm distribute_setup.py
ADD . /docker-registry
RUN cd /docker-registry && pip install -r requirements.txt
RUN cp --no-clobber /docker-registry/config.yml /docker-registry/config/config.yml

EXPOSE 5000

CMD cd /docker-registry && ./setup-configs.sh && ./run.sh
EOF
docker build -t emk/registry .

# Install an Upstart config file for our registry and (re)start it.
# Based on http://docs.docker.io/en/latest/use/host_integration/
cat <<EOF > /etc/init/docker-registry.conf
description "Docker registry"
author "Eric Kidd"
start on filesystem and started docker
stop on runlevel [!2345]
respawn
script
  # Wait for docker to finish starting up first.
  FILE=/var/run/docker.sock
  while [ ! -e /var/run/docker.sock ] ; do
    inotifywait -t 2 -e create /var/run/
  done
  /usr/bin/docker run -rm -p 127.0.0.1:5000:5000 -v /data/registry:/data/registry  emk/registry
end script
EOF
service docker-registry restart

# Install our gitreceive hooks.
cd /usr/local/bin
wget -N https://raw.github.com/progrium/gitreceive/master/gitreceive
chmod +x gitreceive
if [ ! -x /home/git/receiver ]; then 
    gitreceive init
fi
cat <<'EOF' > /home/git/receiver
#!/bin/bash -e

# Decide on an image tag.
name="emk/$(basename $1 .git)"

# Store our exported git tree in a temp directory (and make sure we delete
# it on exit).
WORKDIR=$(mktemp -d build-imageXXXXXX)
function cleanup {
  rm  -rf "$WORKDIR"
}
trap cleanup EXIT
cat | tar -x -C "$WORKDIR"

# Build our docker image.
cd "$WORKDIR"
docker build -t "$name" .
EOF
usermod -a -G docker git
