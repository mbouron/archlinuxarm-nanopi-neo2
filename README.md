This repository can be used to create an ArchLinuxARM image for the NanoPi Neo2
board.


## Dependencies

- `make`
- `bsdtar` (`libarchive`)
- `uboot-tools`
- `swig`
- `sudo`
- `aarch64-linux-gnu-gcc`


## Preparing the files

Run `make` (specifying jobs with `-jX` is supported and recommended).

This will provide:

- the ArchLinuxARM aarch64 default rootfs (`ArchLinuxARM-aarch64-latest.tar.gz`)
- an u-boot image compiled for the NanoPi Neo2 (`u-boot-sunxi-with-spl.bin`)
- a boot script (`boot.scr`) to be copied in `/boot`


## Installing the distribution

Run `make install BLOCK_DEVICE=/dev/mmcblk0` with the appropriate value for
`BLOCK_DEVICE`.


## Goodies

If you have a serial cable and `python-pyserial` installed, `make serial` will
open a session with the appropriate settings.


## TODO

- upstream to ArchLinuxARM
