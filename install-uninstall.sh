#!/bin/sh

set -ex

case $1 in
	'install')
		cp chroot-scripts/* /usr/local/bin
		cp deb-builder.sh /usr/local/bin
	;;

	'uninstall')
		sudo rm /usr/local/bin/deb-checks.sh
		sudo rm /usr/local/bin/chroot-env.sh
		sudo rm /usr/local/bin/deb-builder.sh
	;;

	*) echo "Please, use 'install' or 'uninstall option'" ;;
esac
