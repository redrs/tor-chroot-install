tor-chroot-install
==================

Automatic installation of Tor in a chroot. For Debian systems.

This script will:

* Download Tor source code + check the pgp signature.
* Create chroot, tor user, chroot wrapper init scripts.
* apt-get geoip-database libgeoip1 libssl-dev libevent-dev 
* Compile Tor, install in chroot.
* Copy libs and other files needed to chroot.
* To start with basic config run "/etc/init.d/tor-chroot start"

Tested with Debian 6.0.7 and Tor 0.2.3.25.