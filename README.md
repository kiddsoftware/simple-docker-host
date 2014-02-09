## Running locally with Vagrant

To build and provision a server in Vagrant:

    vagrant up

To configure your account on the server:

    cat ~/.ssh/id_rsa.pub | vagrant ssh -c "sudo gitreceive upload-key `whoami`"

To deploy a project to the server, make sure it has a `Dockerfile` and a
`myproject.conf` file telling Upstart how to run it (see below).  Then run:

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

Once your kernel is ready, upload and run the `configure-system.sh` script
as root.  This should finish configuring the system.

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

...and the following `apache2-demo.conf` file:

    description "Apache 2 demo server"
    author "Eric Kidd"
    start on filesystem and started docker
    stop on runlevel [!2345]
    respawn
    console log
    kill signal SIGINT
    exec /usr/bin/docker run -rm -p 80:80 apache2-demo

Commit these two files using git and run:

    git remote add docker-dev git@docker-dev.local:apache2-demo.git
    git push docker-dev master

Once this is up and running, visit the following URL in your browser:

    http://docker-dev.local/
