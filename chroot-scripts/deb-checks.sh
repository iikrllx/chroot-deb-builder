#!/bin/sh

set -ex

mv bin/* .
rm -rf chroot-checks
mkdir chroot-checks

dsc=$(ls *.dsc)
package=$(echo $dsc | awk -F_ '{print $1}')

debi *amd64.changes > chroot-checks/debi || true
adequate $package > chroot-checks/adequate || true
hardening-check $(which $package) > chroot-checks/hardening-check || true
sudo -u $SUDO_USER lintian -i -I --show-overrides *amd64.changes \
--tag-display-limit 0 > chroot-checks/lintian

mv *deb bin

piuparts -d sid --install-recommends --install-purge-install --warn-on-others \
--warn-on-leftovers-after-purge bin/* > chroot-checks/piuparts-sid 2>&1 || true

piuparts -d bookworm --install-recommends --install-purge-install --warn-on-others \
--warn-on-leftovers-after-purge bin/* > chroot-checks/piuparts-bookworm 2>&1 || true

piuparts -d bookworm -d sid --install-recommends --install-purge-install --warn-on-others \
--warn-on-leftovers-after-purge bin/* > chroot-checks/piuparts-bookworm-sid 2>&1 || true

chown -R $SUDO_USER: chroot-checks
