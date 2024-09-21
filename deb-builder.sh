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
Wrapper for pbuilder, pdebuild and debootstrap.
Build a Debian package in a chroot.

  Options:
  --mirror [suite]                           create system from 'http://deb.debian.org/debian' URL
  --iso [suite] [iso-full-path]              create system from ISO file 'file://media/cdrom' URL
  --login [path-to-tgz]                      login to tgz
  --login-save [path-to-tgz]                 login to tgz with save mode
  --build [path-to-tgz]                      default build package (clean)
  --build-debug [path-to-tgz]                package build with including debug symbols
  --sound                                    make sound after build (use together with build options)

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

	mkdir $result_dir/$dir_format/bin
	mv $result_dir/$dir_format/*.deb $result_dir/$dir_format/bin
	cp ../*orig.tar.* $result_dir/$dir_format
	cp ../*.build $result_dir/$dir_format

	find $result_dir/$dir_format -type f -exec chmod 644 {} +
	chown -R ${SUDO_USER}: $result_dir/$dir_format

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

	if (( $sound_option )); then
		wav_path=/usr/share/sounds/for-deb-builder/prompt.wav
		[ -e $wav_path ] && aplay $wav_path
	fi
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
		[ "$3" == "--sound" ] && sound_option=1

		# nocheck - not run tests
		#export DEB_BUILD_OPTIONS='nocheck'
		_pdebuild $2

		upload=/srv/ftp/upload
		if [ -d $upload ]; then
			f=$(basename $(find $result_dir/$dir_format -name *.dsc -type f))
			ff=${f/.dsc}

			[ -d $upload/$ff ] && rm -rf $upload/$ff
			mkdir $upload/$ff

			cp -r $result_dir/$dir_format/* $upload/$ff
			chown -R ${SUDO_USER}: $upload/$ff
		fi
	;;

	"--build-debug")
		[ -z $2 ] && usage 1
		[ "$3" == "--sound" ] && sound_option=1

		# noopt - O0 / nostrip - debug symbols have / debug - enable debug info
		export DEB_BUILD_OPTIONS='nocheck noopt nostrip debug'
		_pdebuild $2

		touch $result_dir/$dir_format/bin/DEBUG
		chown ${SUDO_USER}: $result_dir/$dir_format/bin/DEBUG
	;;

	"-h"|"--help")
		usage 0
	;;

	*)
		usage 1
	;;
esac
