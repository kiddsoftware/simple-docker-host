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

# Don't start things which depend on Docker until it's actually present.
if ! grep post-start /etc/init/docker.conf; then
  cat <<EOF >> /etc/init/docker.conf

post-start script
    while [ ! -e /var/run/docker.sock ] ; do
      inotifywait -t 2 -e create /var/run/
    end
end script
EOF
fi

# Reload our newly-configured Docker.
service docker restart

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
name="$(basename $1 .git)"

# Store our exported git tree in a temp directory (and make sure we delete
# it on exit).
echo "-----> Unpacking source tree"
WORKDIR=$(mktemp -d build-imageXXXXXX)
function cleanup {
    rm  -rf "$WORKDIR"
}
trap cleanup EXIT
cat | tar -x -C "$WORKDIR"

# Build our docker image.
cd "$WORKDIR"
echo "-----> Building image: $name"
docker build -t "$name" .

# Install our upstart goodies if we have them.
if [ -e "$name.conf" ]; then
    echo "-----> Registering image with upstart: $name"
    sudo cp "$name.conf" /etc/init
    echo "-----> Launching image: $name"
    sudo service "$name" restart
fi
EOF
usermod -a -G docker git # Gives full root privileges via docker.
usermod -a -G admin git  # Gives full root privileges via sudo.

echo "Successfully provisioned host!"
