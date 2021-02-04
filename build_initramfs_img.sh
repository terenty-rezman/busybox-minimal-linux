#!/bin/sh

cd ./initramfs
find . | cpio -H newc -o > ../initramfs.img
cd ..
