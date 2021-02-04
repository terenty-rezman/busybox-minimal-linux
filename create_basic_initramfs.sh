#!/usr/bin/env bash

set -e # terminate script on error

TARGET_RAMFS_DIR="initramfs"
BUSYBOX_ROOTFS_DIR="busybox_rootfs"

# check if user root
#if [[ $EUID != 0 ]]; then
#  echo "! the script is meant to be run with sudo"
#  exit 1 
#fi

[ -d "$TARGET_RAMFS_DIR" ] && { echo $TARGET_RAMFS_DIR already exists ! stop.; exit 1; }

mkdir -p "$TARGET_RAMFS_DIR"

# copy busybox rootfs content to target initramfs dir
cp -av "$BUSYBOX_ROOTFS_DIR"/. "$TARGET_RAMFS_DIR"/

cd "$TARGET_RAMFS_DIR"

# create missing root hierarchy
mkdir -p {bin,dev,etc,home,mnt,proc,sys,usr,tmp,run,var,var/run}

sudo mknod dev/null c 1 3
sudo mknod dev/zero c 1 5
sudo mknod dev/console c 5 1

# create /init script
cat > init << "EOF"
#!/bin/sh

#mdev -s

#exec /sbin/getty -L console 0 vt10
exec /sbin/init
EOF

chmod +x init

# create basic /etc/profile
cat > etc/profile << "EOF"
alias ll='ls -l'

RED="\e[91m"
GREEN="\e[92m"
NORMAL="\e[39m"

case `id -u` in
  0) COLOR="$RED";;
  *) COLOR="$GREEN";;
esac

PS1="${COLOR}$USER ${NORMAL}\w ${COLOR}# $NORMAL"

unset RED
unset GREEN
unset NORMAL
EOF

# create basic /etc/passwd
cat > etc/passwd << "EOF"
root::0:0:root:/root:/bin/sh
EOF

# create /etc/network/interfaces
mkdir -p etc/network

cat > etc/network/interfaces << "EOF"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p etc/network/if-down.d
mkdir -p etc/network/if-post-down.d
mkdir -p etc/network/if-pre-up.d
mkdir -p etc/network/if-up.d

touch etc/resolv.conf

cat > etc/hosts << "EOF"
127.0.0.1 localhost
EOF

cat > etc/hostname << "EOF"
custom
EOF

cp /etc/services etc/services
cp /etc/protocols etc/protocols

# create /etc/nsswitch.conf
cat > etc/nsswitch.conf << "EOF"
# /etc/nsswitch.conf

passwd:         files
group:          files
shadow:         files

hosts:          files dns
networks:       files dns

protocols:      files
services:       files
ethers:         files
rpc:            files
EOF

# create /etc/inittab for busybox init system
cat > etc/inittab << "EOF"
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mkdir -p /dev/pts
::sysinit:/bin/mkdir -p /dev/shm
::sysinit:/bin/mount -a
::sysinit:/bin/hostname -F /etc/hostname
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/etc/init.d/rcK
::shutdown:/sbin/swapoff -a
::shutdown:/bin/umount -a -r
EOF

# create run scripts rcS and rcK
mkdir -p etc/init.d

cat > etc/init.d/rcS << "EOF"
#!/bin/sh

# Start all init scripts in /etc/init.d
# executing them in numerical order.
#
for i in /etc/init.d/S??* ;do

     # Ignore dangling symlinks (if any).
     [ ! -f "$i" ] && continue

     case "$i" in
        *.sh)
            # Source shell script for speed.
            (
                trap - INT QUIT TSTP
                set start
                . $i
            )
            ;;
        *)
            # No sh extension, so fork subprocess.
            $i start
            ;;
    esac
done
EOF

chmod +x etc/init.d/rcS

cat > etc/init.d/rcK << "EOF"
#!/bin/sh

# Stop all init scripts in /etc/init.d
# executing them in reversed numerical order.
#
for i in $(ls -r /etc/init.d/S??*) ;do

     # Ignore dangling symlinks (if any).
     [ ! -f "$i" ] && continue

     case "$i" in
        *.sh)
            # Source shell script for speed.
            (
                trap - INT QUIT TSTP
                set stop
                . $i
            )
            ;;
        *)
            # No sh extension, so fork subprocess.
            $i stop
            ;;
    esac
done
EOF

chmod +x etc/init.d/rcK

# create fstab for "mount -a" line in /etc/inittab
cat > etc/fstab << "EOF"
# <file system>          <mount pt>              <type>    <options>                    <dump>    <pass>
/dev/root                /                       ext2      rw,noauto                    0         1
proc                     /proc                   proc      defaults                     0         0
devpts                   /dev/pts                devpts    defaults,gid=5,mode=620      0         0
tmpfs                    /dev/shm                tmpfs     mode=0777                    0         0
tmpfs                    /tmp                    tmpfs     mode=1777                    0         0
tmpfs                    /run                    tmpfs     mode=0755,nosuid,nodev       0         0
sysfs                    /sys                    sysfs     defaults                     0         0
debugfs                  /sys/kernel/debug       debugfs   defaults                     0         0
EOF

# 
# give ownership to root
#chown -R root:root .

echo done !
