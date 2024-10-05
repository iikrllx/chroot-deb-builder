#!/bin/sh

set -ex

mv bin/* .
rm -rf chroot-checks
mkdir chroot-checks

dsc=$(ls *.dsc)
changes=$(ls *amd64.changes)
package=$(echo $dsc | awk -F_ '{print $1}')

debi $changes > chroot-checks/debi 2>&1 || true
adequate $package > chroot-checks/adequate 2>&1 || true
hardening-check $(which $package) > chroot-checks/hardening-check 2>&1 || true
blhc --all --debian --arch=amd64 *amd64.build > chroot-checks/blhc 2>&1 || true
sudo -u $SUDO_USER lintian -i -I --show-overrides $changes \
--tag-display-limit 0 > chroot-checks/lintian 2>&1 || true

piuparts -d sid --install-recommends --warn-on-others \
--warn-on-leftovers-after-purge $changes > chroot-checks/piuparts-sid 2>&1 || true

piuparts -d bookworm --install-recommends --warn-on-others \
--warn-on-leftovers-after-purge $changes > chroot-checks/piuparts-bookworm 2>&1 || true

piuparts -d bookworm -d sid --install-recommends --warn-on-others \
--warn-on-leftovers-after-purge $changes > chroot-checks/piuparts-bookworm-sid 2>&1 || true

dpkg-source -x $dsc
mkdir tmp
mv $package-* tmp
cd tmp/$package-*
apt-get -y build-dep . >/dev/null
export DEB_BUILD_OPTIONS='nocheck'
dpkg-depcheck -b dpkg-buildpackage -b -uc > ../../chroot-checks/dpkg-depcheck 2>&1 || true
sed -ni '/Packages needed:/,$p' ../../chroot-checks/dpkg-depcheck
cd -; rm -rf tmp

mv *deb bin
chown -R $SUDO_USER: chroot-checks
