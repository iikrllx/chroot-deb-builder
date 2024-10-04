#!/bin/bash

set -ex

if [ $(id -u) != 0 ]; then
	>&2 echo -e "\e[91mERROR (!) Required: id == 0\e[0m"
	exit 1
fi

usage()
{
if (( $1 )); then
	>&2 echo "Try '$(basename $0) --help' for more information"
	exit 1
else
cat << EOF
$(echo -e "\e[96mUsage: $(basename $0) [options]\e[0m")
Script wrapper for pdebuild, pbuilder, debootstrap.
Build a Debian package in a chroot with some checks.

  Options:
  --mirror [suite]                           create system from 'http://deb.debian.org/debian' URL
  --iso [suite] [iso-full-path]              create system from ISO file 'file://media/cdrom' URL
  --login [path-to-tgz]                      login to tgz
  --login-save [path-to-tgz]                 login to tgz with save mode
  --build [path-to-tgz]                      default build package without tests (nocheck)
  --build [path-to-tgz] with-tests           default build package with tests
  --build-debug [path-to-tgz]                package build with including debug symbols

EOF

exit 0
fi
}

arch=amd64

debootstrap_cmd()
{
	trap 'rm -rf $target; umount /media/cdrom &>/dev/null' SIGINT ERR
	debootstrap --no-check-gpg --components=main,contrib,non-free --arch=$arch $suite $target "$1"
}

mount_staff()
{
	mount --bind /dev $1/dev
	mount --bind /dev/pts $1/dev/pts
	mount --bind /proc $1/proc
	mount --bind /sys $1/sys
}

create_chroot()
{
	suite="$2"
	iso_name="${3##*/}"

	[ -z $iso_name ] && target="/$suite-chroot${iso_name/.iso}" || \
	target="/$suite-chroot-${iso_name/.iso}"

	if mount | grep $target &>/dev/null; then
		>&2 echo -e "\e[91mERROR (!) chroot '$target' already to use\e[0m"
		exit 1
	fi

	if [ ! -d $target ]; then
		if [ "$1" == "--mirror" ]; then
			debootstrap_cmd "http://deb.debian.org/debian"
		else
			mount $3 /media/cdrom
			debootstrap_cmd "file:///media/cdrom"
			umount /media/cdrom
		fi
	fi

	cp /usr/local/bin/chroot-env.sh $target/usr/local/bin
	cp /usr/local/bin/deb-checks.sh $target/usr/local/bin
	cp /etc/hosts $target/etc
	mount_staff $target
}

umount_staff()
{
	for mp in proc dev/pts dev sys; do
		umount $1/$mp &>/dev/null
	done
}

launch()
{
	create_chroot $1 $2 $3
	trap 'umount_staff $target' SIGINT ERR
	LANG=C chroot $target chroot-env.sh $suite
	umount_staff $target

	[ -e /var/cache/pbuilder${target}.tgz ] && rm /var/cache/pbuilder${target}.tgz
	cd $target; tar -cvzf /var/cache/pbuilder${target}.tgz *
	[ -e /var/cache/pbuilder${target}.tgz ] && rm -rf $target
}

_pdebuild()
{
	dir_format=$(date "+D:%d-%m-%y+T:%T")
	result_dir=/var/cache/pbuilder/result

	pdebuild --debbuildopts --source-option='-itags' \
	-- --no-auto-cross --basetgz $1 --buildresult $result_dir/$dir_format 2>&1

	chown $SUDO_USER: $(find ../ -maxdepth 1 -type f)
	cp ../*orig.tar.* $result_dir/$dir_format
	cp ../*amd64.build $result_dir/$dir_format

	for link in last prelast; do
		[ -L $result_dir/$link ] && rm $result_dir/$link
	done

	# get recently added dirs
	ldir=$(find /var/cache/pbuilder/result/* -maxdepth 0 -type d -exec ls -1td {} +)

	ln -s $(basename $(echo "$ldir" | head -1)) $result_dir/last
	if (( $(echo "$ldir" | wc -l) > 1 )); then
		ln -s $(basename $(echo "$ldir" | sed -n 2p)) $result_dir/prelast
	fi

	unset DEB_BUILD_OPTIONS
}

# follow debian policy recommendations using tools
post_build_tasks()
{
	mkdir $result_dir/$dir_format/checks
	duck > $result_dir/$dir_format/checks/duck 2>&1 >/dev/null || true
	licensecheck . > $result_dir/$dir_format/checks/licensecheck || true

	blhc --all --debian --arch=amd64 ../*amd64.build > \
	$result_dir/$dir_format/checks/blhc || true

	# before lintian - avoid EACCESS
	chown -R $SUDO_USER: $result_dir/$dir_format

	sudo -u $SUDO_USER lintian -i -I --show-overrides $result_dir/$dir_format/*amd64.changes \
	--tag-display-limit 0 > $result_dir/$dir_format/checks/lintian

	mkdir $result_dir/$dir_format/bin
	# *deb: `udeb` and `deb`
	mv $result_dir/$dir_format/*deb $result_dir/$dir_format/bin

	find $result_dir/$dir_format -type f -exec chmod 644 {} +
	chown -R $SUDO_USER: $result_dir/$dir_format
}

case $1 in
	"--mirror")
		[ $# != 2 ] && usage 1
		launch $1 $2
	;;

	"--iso")
		[ $# != 3 ] && usage 1
		launch $1 $2 $3
	;;

	"--login")
		[ $# != 2 ] && usage 1
		pbuilder --login --basetgz $2
	;;

	"--login-save")
		[ $# != 2 ] && usage 1
		pbuilder --login --save-after-login --basetgz $2
	;;

	"--build")
		[ -z $2 ] && usage 1

		# not run tests
		export DEB_BUILD_OPTIONS='nocheck'

		if [ $3 == "with-tests" ]; then
			unset DEB_BUILD_OPTIONS
		fi

		_pdebuild $2
		post_build_tasks
	;;

	"--build-debug")
		[ -z $2 ] && usage 1

		# nocheck - not run tests
		# noopt - O0
		# nostrip - debug symbols have
		# debug - enable debug info
		export DEB_BUILD_OPTIONS='nocheck noopt nostrip debug'
		_pdebuild $2
		post_build_tasks

		touch $result_dir/$dir_format/bin/DEBUG
		chown $SUDO_USER: $result_dir/$dir_format/bin/DEBUG
	;;

	"-h"|"--help")
		usage 0
	;;

	*)
		usage 1
	;;
esac
