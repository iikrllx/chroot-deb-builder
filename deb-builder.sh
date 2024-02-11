#!/bin/bash

set -ex

if [ $(id -u) != 0 ]; then
	>&2 echo -e "\e[91mERROR (!) Required: id == 0\e[0m"
	exit 1
fi

usage()
{
cat << EOF
$(echo -e "\e[96mUsage: $(basename $0) [options]\e[0m")
Wrapper for debootstrap and pbuilder.
Build a Debian package in chroot.

Options:
  --mirror [suite]                            create system from 'http://deb.debian.org/debian' URL
  --iso [suite] [iso-full-path]               create system from ISO file 'file://media/cdrom' URL
  --login [path-to-tgz]                       login to tgz with save mode
  --build [path-to-tgz]                       clean build package (without dbgsym)
  --build-debug [path-to-tgz]                 package build with including debug symbols
  --build-hardened-only [path-to-tgz]         build hardened kernel + headers
  --build-generic-only [path-to-tgz]          build generic kernel + headers
  --sound                                     make sound after build

EOF
exit $1
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
	target="/$suite-chroot${iso_name/.iso}"

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
	-- --no-auto-cross --basetgz $1 --buildresult $result_dir/$dir_format

	mkdir $result_dir/$dir_format/bin
	mv $result_dir/$dir_format/*.deb $result_dir/$dir_format/bin
	cp ../*orig* $result_dir/$dir_format

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

	if [ "$2" == "--sound" ]; then
		wav_path=/usr/share/sounds/for-script/prompt.wav
		if [ -e $wav_path ]; then
			aplay $wav_path
		fi
	fi
}

case $1 in
	"--mirror") [ ! -z $2 ] && \
		launch $1 $2 ;;

	"--iso") [ ! -z $2 ] && [ ! -z $3 ] && \
		launch $1 $2 $3 ;;

	"--build") [ ! -z $2 ] && \
		# nocheck - not run tests
		export DEB_BUILD_OPTIONS='nocheck'
		_pdebuild $2 $3

		find $result_dir/$dir_format/bin -name "*dbgsym*" -delete

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

	"--build-debug") [ ! -z $2 ] && \
		# noopt - O0 / nostrip - debug symbols have / debug - enable debug info
		export DEB_BUILD_OPTIONS='nocheck noopt nostrip debug'
		_pdebuild $2 $3

		touch $result_dir/$dir_format/bin/DEBUG
		chown ${SUDO_USER}: $result_dir/$dir_format/bin/DEBUG
	;;

	"--login") [ ! -z $2 ] && \
		pbuilder --login --save-after-login --basetgz $2 ;;

	"--build-hardened-only" | "--build-generic-only")
		if [ ! -z $2 ]; then
			pdir=$(dirname $2)
      			custom=$pdir/build/custom
      			package=$(basename `pwd`)

			if [ ! -d $custom ]; then
				mkdir $custom
				tar -xvzf $2 -C $custom
			fi

			[ ! -d $custom/home/builder/$package ] && cp -r $(pwd) $custom/home/builder
			cp /usr/local/bin/builder.sh $custom/usr/local/bin
			mount_staff $custom

			trap 'umount_staff $custom' SIGINT ERR
			LANG=C chroot $custom builder.sh $1 $package
			umount_staff $custom
		fi
	;;

	*) usage 1 ;;
esac
