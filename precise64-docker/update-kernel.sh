export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y linux-image-generic-lts-raring linux-headers-generic-lts-raring
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/g' /etc/default/grub
update-grub
