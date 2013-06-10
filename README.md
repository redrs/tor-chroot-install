tor-chroot-install
==================

Download Tor src and install in chroot. For Debian systems.

This script will:
* Download Tor source code + check the pgp signature.
* Create chroot, tor user, chroot wrapper init scripts.
* apt-get geoip-database libgeoip1 libssl-dev libevent-dev 
* Compile Tor, install in chroot.
* Copy libs and other files needed to chroot.
* To start with basic config run "/etc/init.d/tor-chroot start"