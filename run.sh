#!/bin/sh

./build_initramfs_img.sh && \
qemu-system-x86_64 \
  -kernel ./linux-5.10.11/arch/x86/boot/bzImage \
  -initrd ./initramfs.img \
  -nographic \
  -append "console=ttyS0" \
  -m 256 \
  #--enable-kvm
