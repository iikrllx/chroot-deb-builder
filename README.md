<a href="https://github.com/iikrllx/chroot-deb-builder/tree/master">
    <img src="https://img.shields.io/badge/scripts%20for%20maintainers-blue?style=flat&logo=Debian&logoColor=CE0056&labelColor=white">
</a>

# chroot-deb-builder
Automatic building of a ```deb``` package in a chroot. Maintainers usually do not build packages on
their host machines, but do it in chroots. The ```deb-builder.sh``` script is a wrapper around
```pbuilder```, ```pdebuild``` and ```debootstrap``` (excellent tools that automate the package
building process and chroot creation). ```deb-builder.sh``` combines these tools into one.

## Cloning and installing
```
$ git clone https://github.com/iikrllx/chroot-deb-builder.git
$ cd chroot-deb-builder
$ ./install-uninstall.sh install
```

## Testing
Bootstrap Debian Bullseye:
```
$ sudo deb-builder.sh --mirror bullseye
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
$ sudo deb-builder.sh --build /var/cache/pbuilder/bullseye-chroot.tgz
```
or with sound:
```
$ sudo deb-builder.sh --build /var/cache/pbuilder/bullseye-chroot.tgz --sound
```

The packages will be in: ```/var/cache/pbuilder/result```<br/>
The last actual build: ```/var/cache/pbuilder/result/last```<br/>
The penultimate build: ```/var/cache/pbuilder/result/prelast```<br/>

Go to chroot:
```
$ sudo deb-builder.sh --login /var/cache/pbuilder/bullseye-chroot.tgz
```

## Removal
If you didn't like this project, remove its files as follows:
```
$ ./install-uninstall.sh uninstall
```

## License
This project is licensed under the GPLv3 License - see the
[LICENSE](https://github.com/iikrllx/chroot-deb-builder/blob/master/LICENSE) file for details.
