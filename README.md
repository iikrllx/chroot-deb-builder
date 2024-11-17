<a href="https://github.com/iikrllx/chroot-deb-builder/tree/master">
    <img src="https://img.shields.io/badge/scripts%20for%20maintainers-blue?style=flat&logo=Debian&logoColor=CE0056&labelColor=white">
</a>

# chroot-deb-builder
Builds a Debian package for the amd64 architecture in a chroot environment. Maintainers usually do
not build packages on their host machines, but do it in chroots. The ```deb-builder.sh``` script is
a wrapper around ```pbuilder```, ```pdebuild``` and ```debootstrap``` (excellent tools that automate
the package building process and chroot creation). ```deb-builder.sh``` combines these tools into
one. After the package is successfully built, the script proceeds to run various tools to verify and
ensure the quality of the package. These checks help maintainers ensure that the package is
compliant with Debian standards and is free from common issues before it is uploaded to the
repository.

## Cloning and installing
```
$ git clone https://github.com/iikrllx/chroot-deb-builder.git
$ cd chroot-deb-builder
$ sudo ./install-uninstall.sh install
```

## Testing
Bootstrap Debian Bookworm:
```
$ sudo deb-builder.sh --mirror bookworm
```

Bootstrap a chroot from ISO file:
```
$ sudo deb-builder.sh --iso <suite> /path/to/my/iso
```

Example of building a Debian package:
```
$ mkdir -p ~/sources/coreutils
$ cd ~/sources/coreutils
$ apt-get source coreutils
$ cd coreutils-9.1
```

Usage description:
```
$ sudo deb-builder.sh --help
```

Default package build without tests (nocheck):
```
$ sudo deb-builder.sh --build /var/cache/pbuilder/bookworm-chroot.tgz
```

Default package build with tests:
```
$ sudo deb-builder.sh --build with-tests /var/cache/pbuilder/bookworm-chroot.tgz
```

Package build with including debug symbols:
```
$ sudo deb-builder.sh --build-debug /var/cache/pbuilder/bookworm-chroot.tgz
```

Default package build with Debian checks (lintian, blhc, duck, etc.):
```
$ sudo deb-builder.sh --build-with-checks /var/cache/pbuilder/bookworm-chroot.tgz
```

The packages will be in: ```/var/cache/pbuilder/result```<br/>
The last actual build: ```/var/cache/pbuilder/result/last```<br/>
The penultimate build: ```/var/cache/pbuilder/result/prelast```<br/>

Go to chroot:
```
$ sudo deb-builder.sh --login /var/cache/pbuilder/bookworm-chroot.tgz
```

Go to chroot with the save mode:
```
$ sudo deb-builder.sh --login-save /var/cache/pbuilder/bookworm-chroot.tgz
```

Execute Debian checks within the chroot:
```
$ cd sources/<pbuilder-last-build>
$ sudo deb-checks.sh
```

## Removal
If you don't need these scripts, remove them as follows:
```
$ ./install-uninstall.sh uninstall
```
