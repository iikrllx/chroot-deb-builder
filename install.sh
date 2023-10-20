#!/bin/bash

set -ex

for f in builder.sh chroot-env.sh debootstrap.sh; do
	sudo install $f /usr/local/bin
done

sudo mkdir -p /usr/share/sounds/for-script
sudo install sound/* /usr/share/sounds/for-script

echo $?
