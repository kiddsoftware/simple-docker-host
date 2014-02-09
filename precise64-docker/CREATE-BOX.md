Linode supports Docker in kernel 3.12.  On Ubuntu 12.04 LTS systems, we can
get by with 3.8, which has the advantage of being easily available and
playing nicely with VirtualBox.

We build our base image by replacing the kernel, configuring grub, and
saving the resulting image, so that we don't need to do all this every time
we provision a Docker-compatible image.

Run the following in this directory:

    vagrant plugin install vagrant-vbguest
    vagrant up
    vagrant halt
    vagrant up
    vagrant ssh

Make sure that `vagrant` mounted correctly and everything looks good.  Then
run:

    vagrant package --output=precise64-docker.box
    vagrant box add precise64-docker precise64-docker.box

To install this, run:

    # Remove an older version.
    vagrant box remove precise64-docker
    vagrant box add precise64-docker precise64-docker.box
