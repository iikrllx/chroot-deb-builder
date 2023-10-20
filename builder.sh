#!/bin/bash

set -ex

if [ $(id -u) != 0 ]; then
	>&2 echo "ERROR (!) Required: id == 0"
	exit 1
fi

chown -R builder: /home/builder/$2
cd /home/builder/$2

su builder << EOF
sudo apt-get update
sudo apt-get -y build-dep .
fakeroot debian/rules clean
EOF

[ $1 == "--build-hardened-only" ] && \
su builder << EOF
fakeroot dpkg-buildpackage -b --target=binary-hardened -uc
fakeroot dpkg-buildpackage -b --target=binary-headers -uc
EOF

[ $1 == "--build-generic-only" ] && \
su builder << EOF
fakeroot dpkg-buildpackage -b --target=binary-generic -uc
fakeroot dpkg-buildpackage -b --target=binary-headers -uc
EOF
