#!/bin/bash
#
# Compile Tor and build a chroot
#
# This script will:
# * Download Tor source code + check the pgp signature.
# * Create chroot, tor user, init scripts.
# * apt-get geoip-database libgeoip1 libssl-dev libevent-dev 
# * Compile Tor, install in chroot.
# * Copy libs and other files needed to chroot.
# * To start with basic config "/etc/init.d/tor-chroot start"
#
# Tested with Tor 0.2.3.25 and Debian 6 and 7.0
#
# based on:
# https://trac.torproject.org/projects/tor/wiki/doc/TorInChroot
# https://github.com/ioerror/tor-chroot/

# Vars:
TORSRC="https://www.torproject.org/dist/tor-0.2.3.25.tar.gz"
TORSRCSIG="$TORSRC.asc"

# Install to:
TORCHROOT=/opt/chroot_tor

# Compile flags:
COMPILEOPT=" --prefix=/tor \
--with-tor-user=tor --with-tor-group=tor \
--enable-gcc-hardening --enable-linker-hardening"

###################################################################

fail() {
	echo -e "\n[X] Error: $@ \n" >&2;
	exit 1
}

echo -e "\n[*] Will install Tor to: $TORCHROOT";
echo "[*] Checking build environment"

# System checks.
[ -z "$BASH_VERSION" ] && fail "Need bash"
[ "$(id -u)" != "0" ] && fail "Need to run as root"
[ ! -f  "/etc/debian_version" ] && fail "This script is for Debian"

# Do we have these packages?
PACKAGENEEDS="make geoip-database libgeoip1 libssl-dev libevent-dev"
for thepackage in $PACKAGENEEDS
do
        dpkg-query -W $thepackage &> /dev/null || needthese="$needthese $thepackage"
done
if [ `echo ${needthese} | wc -w` -gt 0 ]; then
        apt-get -y install $needthese || fail "could not: apt-get install $needthese"
fi

# Do we have Tor gpg key?
if [ `gpg --list-keys 19F78451 | wc -l` -eq 0 ]; then
        echo "[*] Don't have Tor gpg keys";
        gpg --recv-keys 19F78451 &> /dev/null || fail "Could not get Tor gpg keys from keyserver"
        GPGKERN=`gpg --fingerprint 19F78451 | grep fingerprint | tr -d ' ' | sed 's/Keyfingerprint\=//g'`
        if [ "$GPGKERN" != "F65CE37F04BA5B360AE6EE17C218525819F78451" ]; then
                fail "Wrong gpg key fingerprint!!"
        fi
        echo "[*] Got Tor gpg keys from keyserver";
fi

# Get source code, check sig, untar.
echo -e "[*] Downloading Tor source code"
wget $TORSRC --no-verbose || fail "Could not download $TORSRC"
wget $TORSRCSIG --no-verbose || fail "Could not download $TORSRC.asc"
TORTAR=`echo $TORSRC | grep -o -P '(?<=dist\/).*(?=)'`
echo -e "[*] Verifying and uncompressing source code"
gpg --verify $TORTAR.asc &> /dev/null || fail "Bad signature"
tar xf $TORTAR || fail "Could not uncompress"

# Add Tor user.
if [ `grep "tor" /etc/passwd | wc -l` -eq 0 ]; then
	adduser --disabled-login --no-create-home --home /var/lib/tordata --shell /bin/false --gecos "Tor user,,," tor || fail "could not create user tor"        
	echo -e "[*] Created user tor"
else
	echo -e "[*] User tor exists"
fi

# Build chroot structure
echo -e "[*] Creating chroot folder structure"
mkdir -p $TORCHROOT
mkdir -p $TORCHROOT/{etc,dev,lib,lib64,usr,usr/lib,var/run/tor/,var/lib/tordata/,var/log/tor/}/
mknod -m 644 $TORCHROOT/dev/random c 1 8
mknod -m 644 $TORCHROOT/dev/urandom c 1 9
mknod -m 666 $TORCHROOT/dev/null c 1 3

# Compile Tor.
cd ${TORTAR%.tar.gz}
echo -e "[*] Running Tor configure script"
echo | ./configure $COMPILEOPT || fail "configure script failed, check options"
echo -e "[*] Running make"
echo | make || fail "failed to make"
echo -e "[*] Running make install"
echo | make install prefix=$TORCHROOT/tor exec_prefix=$TORCHROOT/tor || fail "make install failed"
cd ..

# Copy etc files to chroot.
echo -e "[*] Copying required files/libs to chroot"
cp /etc/nsswitch.conf /etc/host.conf /etc/resolv.conf /etc/hosts $TORCHROOT/etc
cp /etc/localtime $TORCHROOT/etc

grep tor /etc/passwd > $TORCHROOT/etc/passwd
grep tor /etc/group > $TORCHROOT/etc/group

# Geoip file.
cp /usr/share/GeoIP/GeoIP.dat $TORCHROOT/tor/share/tor/geoip || fail "missing geoip database"

# Copy shared libraries to chroot.
cp `ldd $TORCHROOT/tor/bin/tor | awk '{print $3}'|grep "^/"` $TORCHROOT/lib
cp /lib/libnss* /lib/libnsl* /lib/ld-linux.so.2 /lib/libresolv* $TORCHROOT/lib

# Basic Tor config file to get stated with.
echo -e "[*] Copy basic torrc file"
cat << 'EOF' > $TORCHROOT/tor/etc/tor/torrc
# basic tor conf for clients
# all options documented https://www.torproject.org/docs/tor-manual.html.en
User tor
RunAsDaemon 1
PidFile /var/run/tor/tor.pid
GeoIPFile /tor/share/tor/geoip
Log notice file /var/log/tor/notices.log
DataDirectory /var/lib/tordata

SocksPort 127.0.0.1:9050

# make all OR connections through the SOCKS 4 proxy
# Socks4Proxy 127.0.0.1:8080

# not an exit node
ExitPolicy reject *:*
EOF

# Perms
echo -e "[*] File Permissions"
chown root:tor $TORCHROOT -v
chmod 0770 $TORCHROOT -v
chmod 0444 $TORCHROOT/etc/* -v
chmod a+r $TORCHROOT/lib/* -v
chmod 0755 $TORCHROOT/tor{/bin,/etc,/share} -v
chmod 0755 $TORCHROOT/tor/share{/doc,/man,/share}
chown tor:tor $TORCHROOT/var -Rv
chmod 0700 $TORCHROOT/var/lib/tordata -v
chmod 0755 $TORCHROOT{/var/run/tor,/var/log/tor} -v
chmod 0755 $TORCHROOT{/dev,/etc,/lib,/lib64,/usr,/tor,/var,/var/lib} -v

# Install Tor init.d script.
if [ ! -f /etc/init.d/tor-chroot ]; then
	echo -e "[*] Copying Tor init.d scripts"
	cp tor-inid.d-script /etc/init.d/tor-chroot
	chmod 555 /etc/init.d/tor-chroot
fi

# Copy over the Tor chroot wrapper files.
cat << 'EOF' > $TORCHROOT/tor/bin/tor-chroot
#!/bin/bash -x
/usr/sbin/chroot /opt/chroot_tor /tor/bin/tor -f /tor/etc/tor/torrc $*
EOF
chmod 555 $TORCHROOT/tor/bin/tor-chroot

cat << 'EOF' > /etc/default/tor
RUN_DAEMON="yes"
EOF
chmod 400 /etc/default/tor

echo -e "\n[*] Done"