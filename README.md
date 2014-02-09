## What is this?

Right now, there are a bunch of interesting projects trying to make it easy
to deploy services with [Docker][]:

* [Dokku][] provides a miniature Heroku-like environment.  It's tiny and
  clever, but less useful if you want to deploy non-web services.
* [Flynn][] is intended to be a much more ambitous version of Dokku, but it's
  still under development.
* [Deis][] uses Chef to manage services like databases, and a Heroku-style
  interface to manage web apps.  It will soon be able to deploy web apps
  described using a `Dockerfile`, but that's not released yet.
* [CoreOS][] is very clever: It's a bare Linux system running `systemd` (to
  manage servers) and `etcd` (to control cluster configuration).
  Unfortunately, it's hard to get running on many web hosts, and it's still
  early in its development cycle.  And as far as I know, it doesn't offer
  any `git push`-based deployment mechanisms.
* It's also possible to deploy Docker on top of [OpenStack][], assuming
  you have an OpenStack environment.

But none of these quite meet my needs yet.  I'm looking for a system which:

* Is small enough to be installed on a "hobby" server.
* Allows arbitrary docker services to be deployed using `git push`,
  including web apps, mail servers, or anything else which can be
  containerized.
* Provides a forwarding proxy server which can route requests to the correct
  web app.
* Can be deployed in minutes to almost any hosted Ubuntu 12.04 LTS server
  running Linux 3.8 or later.
* Can be run locally with Vagrant for development and testing.
* Is small and unobtrusive enough to be thrown away once one of the above
  projects matures.

The solution: a low-rent CoreOS knockoff using `git push` to create and
deploy images, and Upstart to manage running containers.

[Docker]: http://www.docker.io/
[Dokku]: https://github.com/progrium/dokku
[Flynn]: https://flynn.io/
[Deis]: http://deis.io/
[CoreOS]: https://coreos.com/
[OpenStack]: https://wiki.openstack.org/wiki/Docker

## Running locally with Vagrant

To build and provision a server in Vagrant:

    vagrant up

To configure your account on the server:

    cat ~/.ssh/id_rsa.pub | vagrant ssh -c "sudo gitreceive upload-key `whoami`"

To deploy a project to the server, make sure it has a `Dockerfile` and an
`upstart.conf` file telling Upstart how to run it (see below).  Then run:

    git remote add docker-dev git@docker-dev.local:myproject.git
    git push docker-dev master

This should create the remote git repository, build a docker image named
`myproject`, install `myproject.conf`, and restart the server.

## Running on a hosted Ubuntu server

This hasn't been tested yet, but in theory, you need to make sure the
remote server is running Ubuntu 12.04 LTS with Linux kernel 3.8 or greater.
See [the official Ubuntu instructions][ubuntu] for details on updating the
kernel, but don't bother installing docker itself yet.  For Linode, see
[their blog][linode].  For other hosting environments, search the web.

Take a momement to disable any unnecessary services, turn on automatic
updates, and do any other standard server configuration you like to do.
The goal is produce a server with nothing much except an ssh daemon.

Once your kernel is ready, upload and run the `configure-system.sh` script
as root.  This should finish configuring the system.  This script is
"idempotent", in the usual DevOps sense, which means if you run it more
than once, it shouldn't cause any problems.

Finally, make sure that you can log into the remote server via ssh and use
`sudo`.  Once that's in place, run:

    cat ~/.ssh/id_rsa.pub | ssh example.com -c "sudo gitreceive upload-key `whoami`"
    git remote add myserver git@example.com:myproject.git

[ubuntu]: http://docs.docker.io/en/latest/installation/ubuntulinux/
[linode]: https://blog.linode.com/2014/01/03/docker-on-linode/

## An example service

Create a repository containing the following `Dockerfile`:

    FROM ubuntu:12.04
    
    ENV DEBIAN_FRONTEND noninteractive
    ENV APACHE_LOG_DIR /var/log/apache2
    ENV APACHE_RUN_USER www-data
    ENV APACHE_RUN_GROUP www-data
    
    RUN apt-get update
    RUN apt-get install -y apache2
    
    EXPOSE 80
    
    CMD /usr/sbin/apache2 -DFOREGROUND

...and the following `upstart.conf` file:

    description "Apache 2 demo server"
    author "Eric Kidd"
    start on filesystem and started docker
    stop on runlevel [!2345]
    respawn
    console log
    kill signal SIGINT
    exec /usr/bin/docker run -rm -p 127.0.0.1:8000:80 apache2-demo

Here, we bind port 80 on the container to port 8000 on the host's internal
interface.  If we were setting up a public mail server, we would use `-p
25:25` to bind port 25 on the container to port 25 on the host.  But in the
case of port 80, we're going to want to share it between multiple
containers using a forwarding proxy.  To do this, we need to add a third
file, `nginx-proxy.conf`:

    server {
      listen 80 default_server;
    
      # Run as a catch-all server for demo purposes.
      server_name _;
    
      # Alternatively, see http://wiki.nginx.org/ServerBlockExample for examples
      # on how to set up multiple sites with different hostnames.
      #server_name vhost.example.com;
    
      location / {
        proxy_pass http://127.0.0.1:8000/;
      }
    }

Commit these three files using git and run:

    git init
    git add Dockerfile upstart.conf nginx-proxy.conf
    git commit -m "Create sample apache project"
    git remote add docker-dev git@docker-dev.local:apache2-demo.git
    git push docker-dev master

Once this is up and running, visit the following URL in your browser:

    http://docker-dev.local/
