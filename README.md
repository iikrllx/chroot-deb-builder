# chroot-debianizer
```chroot-debianizer``` is a tool that automates routine work with Debian
packages. Recognizing that maintainers typically do not build packages on their
host machines, ```chroot-debianizer``` builds packages in chroot environments
for the amd64 architecture to ensure a clean and isolated process. This script
serves as a wrapper around ```pbuilder```, ```pdebuild```, and
```debootstrap```, combining these excellent tools into one streamlined
workflow. After the package is successfully built, ```chroot-debianizer``` runs
various tools to verify and ensure the quality of the package. These checks help
maintainers ensure that the package is compliant with Debian standards and free
from common issues before it is uploaded to the repository. I was not satisfied
with the pbuilder hooks, which led me to create my own tool.

## Installation
```
$ curl -L -O https://github.com/iikrllx/chroot-debianizer/releases/download/v1.0.0-1/chroot-debianizer_1.0.0-1_all.deb
$ sudo apt install -y ./chroot-debianizer_1.0.0-1_all.deb
```

## Examples
NOTE: Scripts such as ```chroot-debianizer``` and ```deb-checks.sh``` are
executed with superuser rights.

Usage information:
```
$ chroot-debianizer --help
$ man chroot-debianizer
```

Create a chroot from the Debian mirror:
```
$ chroot-debianizer --mirror bookworm
```

Create a chroot from an ISO file:
```
$ chroot-debianizer --iso bookworm ~/Downloads/debian-12.9.0-amd64-netinst.iso
```

Example of building a Debian package (prepare the sources):
```
$ mkdir sources; cd sources
$ apt-get source hello
$ cd hello-2.10
```

Build package without tests (nocheck):
```
$ chroot-debianizer --build /var/cache/pbuilder/bookworm-chroot.tgz
```

Build package with tests:
```
$ chroot-debianizer --build /var/cache/pbuilder/bookworm-chroot.tgz with-tests
```

Build package with debug symbols:
```
$ chroot-debianizer --build-debug /var/cache/pbuilder/bookworm-chroot.tgz
```

Build package with Debian checks like ```lintian```, ```blhc```, ```lrc```,
```duck```, etc:
```
$ chroot-debianizer --build-with-checks /var/cache/pbuilder/bookworm-chroot.tgz
```

The packages will be in: ```/var/cache/pbuilder/result/last/bin```<br/>
The last actual build: ```/var/cache/pbuilder/result/last```<br/>
The penultimate build: ```/var/cache/pbuilder/result/prelast```<br/>

Login to tgz:
```
$ chroot-debianizer --login /var/cache/pbuilder/bookworm-chroot.tgz
```

Login to tgz with save mode:
```
$ chroot-debianizer --login-save /var/cache/pbuilder/bookworm-chroot.tgz
```

### Execute Debian checks within the chroot
Perform more complex checks like ```piuparts```, ```hardening-check```,
```adequate```, etc.

First, log in to the chroot environment:
```
$ chroot-debianizer --login /var/cache/pbuilder/bookworm-chroot.tgz
```

From another terminal, copy files to the chroot:
```
$ cp -r /var/cache/pbuilder/result/last/* /var/cache/pbuilder/build/<pid>/home/builder/sources/
```

Return to the original terminal and run additional checks:
```
$ cd sources/<my-last-build>
$ deb-checks.sh
```
