SERIAL_DEVICE = /dev/ttyUSB0
WGET = wget
MINITERM = miniterm.py
CROSS_COMPILE ?= aarch64-linux-gnu-
PYTHON ?= python2
BLOCK_DEVICE ?= /dev/null
FIND ?= find

TRUSTED_FIRMWARE_VERSION = 2.14.0
TRUSTED_FIRMWARE_TARBALL = arm-trusted-firmware-v$(TRUSTED_FIRMWARE_VERSION).tar.gz
TRUSTED_FIRMWARE_DIR = arm-trusted-firmware-$(TRUSTED_FIRMWARE_VERSION)
TRUSTED_FIRMWARE_BIN = bl31.bin

UBOOT_SCRIPT = boot.scr
UBOOT_BIN = u-boot-sunxi-with-spl.bin

ARCH_TARBALL = ArchLinuxARM-aarch64-latest.tar.gz

UBOOT_VERSION = 2018.09-rc2
UBOOT_TARBALL = u-boot-v$(UBOOT_VERSION).tar.gz
UBOOT_DIR = u-boot-$(UBOOT_VERSION)

MOUNT_POINT = mnt

ALL = $(ARCH_TARBALL) $(UBOOT_BIN) $(UBOOT_SCRIPT)

all: $(ALL)

$(TRUSTED_FIRMWARE_TARBALL):
	$(WGET) https://github.com/ARM-software/arm-trusted-firmware/archive/refs/tags/v$(TRUSTED_FIRMWARE_VERSION).tar.gz -O $@
$(TRUSTED_FIRMWARE_DIR): $(TRUSTED_FIRMWARE_TARBALL)
	tar xf $<
$(TRUSTED_FIRMWARE_BIN): $(TRUSTED_FIRMWARE_DIR)
	cd $< && make PLAT=sun50i_a64 DEBUG=1 bl31 CROSS_COMPILE=$(CROSS_COMPILE)
	cp $</build/sun50i_a64/debug/$@ .

$(UBOOT_TARBALL):
	$(WGET) https://github.com/u-boot/u-boot/archive/v$(UBOOT_VERSION).tar.gz -O $@
$(UBOOT_DIR): $(UBOOT_TARBALL)
	tar xf $<

$(ARCH_TARBALL):
	$(WGET) http://archlinuxarm.org/os/$@

$(UBOOT_BIN): $(UBOOT_DIR) $(TRUSTED_FIRMWARE_BIN)
	cd $< && $(MAKE) nanopi_neo2_defconfig && $(MAKE) CROSS_COMPILE=$(CROSS_COMPILE) PYTHON=$(PYTHON) BL31=../$(TRUSTED_FIRMWARE_BIN)
	cat $(UBOOT_DIR)/spl/sunxi-spl.bin $(UBOOT_DIR)/u-boot.itb > $@

# Note: non-deterministic output as the image header contains a timestamp and a
# checksum including this timestamp (2x32-bit at offset 4)
$(UBOOT_SCRIPT): boot.txt
	mkimage -A arm64 -O linux -T script -C none -n "U-Boot boot script" -d $< $@
boot.txt:
	$(WGET) https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/alarm/uboot-pine64/$@
	sed -i "s/sun50i.*/sun50i-h5-nanopi-neo2.dtb/" $@

serial:
	$(MINITERM) --raw --eol=lf $(SERIAL_DEVICE) 115200
define part1
/dev/$(shell basename $(shell $(FIND) /sys/block/$(shell basename $(1))/ -maxdepth 2 -name "partition" -printf "%h"))
endef

install: $(UBOOT_BIN) $(UBOOT_SCRIPT) $(ARCH_TARBALL) fdisk.cmd
ifeq ($(BLOCK_DEVICE),/dev/null)
	@echo You must set BLOCK_DEVICE option
else
	sudo dd if=/dev/zero of=$(BLOCK_DEVICE) bs=1M count=8
	sudo fdisk $(BLOCK_DEVICE) < fdisk.cmd
	sudo mkfs.ext4 $(call part1,$(BLOCK_DEVICE))
	mkdir -p $(MOUNT_POINT)
	sudo umount $(MOUNT_POINT) || true
	sudo mount $(call part1,$(BLOCK_DEVICE)) $(MOUNT_POINT)
	sudo bsdtar -xpf $(ARCH_TARBALL) -C $(MOUNT_POINT)
	sudo cp $(UBOOT_SCRIPT) $(MOUNT_POINT)/boot
	sync
	sudo umount $(MOUNT_POINT) || true
	rmdir $(MOUNT_POINT) || true
	sudo dd if=$(UBOOT_BIN) of=$(BLOCK_DEVICE) bs=1024 seek=8
endif

clean:
	$(RM) $(ALL)
	$(RM) boot.txt
	$(RM) -r $(UBOOT_DIR)

.PHONY: all serial clean install
