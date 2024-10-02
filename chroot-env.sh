#!/bin/bash

set -ex

cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $1 main contrib non-free
deb-src http://deb.debian.org/debian $1 main contrib non-free
EOF

packages=(dialog sudo locales vim mc gcc make bash-completion xsel \
build-essential dpkg-dev devscripts debhelper dh-make fakeroot \
eatmydata aptitude apt-file lintian adequate piuparts blhc)

apt-get update
for pack in ${packages[*]}; do
	if ! dpkg -l | awk '{print $2}' | grep ^$pack$ &>/dev/null; then
		DEBIAN_FRONTEND=noninteractive apt-get -y install $pack
	fi
done

user=builder pass=1
useradd -m $user -s /bin/bash
echo "$user:1" | chpasswd 2>/dev/null
echo "$user ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

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

echo >> /etc/bash.bashrc
echo "alias mc='mc -S gotar'" >> /etc/bash.bashrc
echo "TERM=xterm-256color" >> /etc/bash.bashrc

cat << \EOF >> /home/$user/.bashrc

export LANG=en_US.UTF8
export LC_ALL=en_US.UTF-8
export HISTCONTROL=ignoredups
export EDITOR='/usr/bin/vim'
export DEBEMAIL=krekhov.dev@gmail.com
export DEBFULLNAME="Kirill Rekhov"

alias cc='xsel -p -c; xsel -b -c' # clear primary/clipboard selections
alias daterc='date -R | xsel -b -i' # input date (RFC 5322) to clipboard (for changelog)
alias _date='date +"%d/%m/%Y - %H:%M:%S"' # simple format
alias ls='ls -1l --group-directories-first -hN --color'
alias la='ls -A --color'
alias grep='grep --color'
alias diff='diff --color'
alias rm='rm -v'
alias cp='cp -vi'
alias mv='mv -vi'
alias mkdir='mkdir -v'
alias a='sudo aptitude'
alias v='vim'

# touch file with verbose mode =)
vtouch()
{
    for i do
        touch "$i"
        [ $? == 0 ] && echo "touched: '$i'"
    done
} && alias touch='vtouch'

EOF

mkdir /home/$user/sources
chown $user: /home/$user/sources
