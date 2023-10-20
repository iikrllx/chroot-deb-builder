#!/bin/bash

set -ex

if [ $(id -u) != 0 ]; then
	>&2 echo "ERROR (!) Required: id == 0"
	exit 1
fi

if [ -z $1 ]; then
	>&2 echo "ERROR (!) Argument missed (suite)"
	exit 1
fi

cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $1 main contrib non-free
deb-src http://deb.debian.org/debian $1 main contrib non-free
EOF

packages=(dialog sudo locales vim mc gcc make bash-completion \
build-essential dpkg-dev devscripts debhelper dh-make fakeroot eatmydata \
aptitude)

apt-get update
for pack in ${packages[*]}; do
	if ! dpkg -l | awk '{print $2}' | grep ^$pack$ &>/dev/null; then
		DEBIAN_FRONTEND=noninteractive apt-get -y install $pack
	fi
done

user=builder pass=1
if ! id -u $user 2>/dev/null; then
	# this shit need to create home directory
	# because 'useradd -m <user>' not working in my chroot ...
	mkdir /home/$user
	[ ! -d /etc/skel ] && exit 1
	# copy all dot files
	cp -r /etc/skel/. /home/$user
	useradd $user -s /bin/bash
	echo "$user:$pass" | chpasswd 2>/dev/null
	echo "$user ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

for loc in en_US.UTF-8 ru_RU.UTF-8; do
	if ! grep ^$loc /etc/locale.gen &>/dev/null; then
		echo "$loc UTF-8" | sudo tee -a /etc/locale.gen
		locale-gen
	fi
done

# enable bash completion
perl -i -pe '$i++ if /^#if ! shopt -oq posix;/; s/^#// if $i==1; $i=0 if /^fi/' /etc/bash.bashrc

# sudo prompt add suite
sed -i "s/PS1='\${debian_chroot/PS1='$1-\${debian_chroot/" /etc/bash.bashrc

echo "TERM=xterm-256color" >> /etc/bash.bashrc

cat << EOF >> /home/$user/.bashrc

export HISTCONTROL=ignoredups
export EDITOR='/usr/bin/vim'
EOF
