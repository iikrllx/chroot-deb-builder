#!/bin/bash

set -ex

case $1 in
	'install')
		for f in chroot-env.sh deb-builder.sh; do
			sudo install $f /usr/local/bin
		done

		sudo mkdir -p /usr/share/sounds/for-deb-builder
		sudo install sound/* /usr/share/sounds/for-deb-builder
	;;

	'uninstall')
		for f in chroot-env.sh deb-builder.sh; do
			sudo rm /usr/local/bin/$f
		done

		sudo rm -rf /usr/share/sounds/for-deb-builder
	;;

	*) echo "Please, use 'install' or 'uninstall option'" ;;
esac
