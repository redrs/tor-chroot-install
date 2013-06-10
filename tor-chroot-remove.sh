#!/bin/bash

# remove Tor chroot files

TORCHROOT=/opt/chroot_tor/

echo -e "\nRemove all Tor chroot files.\n"
echo -e "To continue press: Y \n"

read -p "Proceed? " SELECTED

if [ "$SELECTED" = "Y" ]; then

        rm $TORCHROOT -rfv || echo "Could not rm $TORCHROOT"
        rm /etc/default/tor -rfv || echo "Could not rm /etc/default/tor"
        rm /etc/init.d/tor-chroot -rfv || echo "Could not rm tor-chroot init script."
        userdel tor -f || echo "Could not run: userdel tor"

        echo -e "\nDone, all Tor files removed."
fi