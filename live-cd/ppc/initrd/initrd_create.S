#!/bin/bash
# initrd_create:  make initrd rootdisk by using busybox
#
# Author:	  Tomas M. <http://www.linux-live.org>

. ../config || exit 1

# rcopy is a recursive cp, which copies also symlink's real source
# $1 = source (may be a regular file or symlink)
# $2 = target PARENT
#
rcopy()
{
   if [ -L "$1" ]; then
      REALPATH="`readlink -f \"$1\"`"
      cp --parent -R "$REALPATH" "$2"
      ln -sf "$REALPATH" "$2/$1"
   else
      cp --parent -R "$1" "$2"
   fi
   if [ "$?" -ne 0 ]; then
      echo "---------------------------"
      echo "Error occured while trying to copy \"$1\" to \"$2\""
      echo "nevertheless your LiveCD may still work."
      echo "Possible reason: not enough free space in initrd or source doesn't exist"
      echo "---------------------------"
   fi
}

# copy file/dir only if it exists, else skip with no error
# $1 = source (may not exist)
# $2 = target PARENT
#
rcopy_ex()
{
   if [ -a "$1" ]; then
      rcopy "$1" "$2"
   fi
}

debug()
{
   # uncomment to show debug messages
   # echo "$@"
   return 0
}

##################################################
# Create INITRD image now:

MOUNTDIR=/tmp/initrd_mountdir_$$
INITRD_TREE=/tmp/initrd_tree_$$

#if [ ! -d "kernel-modules/$KERNEL" ]; then
if [ ! -d "/lib/modules/$KERNEL" ]; then
   echo "The directory kernel-modules/$KERNEL doesn't exist. Please create it and copy"
   echo "squashFS and unionFS modules for your kernel version to it."
   exit 1
fi

echo "creating empty directory $INITRD_TREE"
rm -Rf $INITRD_TREE
mkdir $INITRD_TREE

echo "creating directories"
mkdir -p $INITRD_TREE/{etc,dev,bin,mnt,proc,lib,sbin,sys,tmp,var/log}

echo "creating some essential devices in rootdisk"
mknod $INITRD_TREE/dev/console c 5 1
mknod $INITRD_TREE/dev/null c 1 3
mknod $INITRD_TREE/dev/ram b 1 1
mknod $INITRD_TREE/dev/systty c 4 0
mknod $INITRD_TREE/dev/tty c 5 0
mknod $INITRD_TREE/dev/tty1 c 4 1

loops=255
while [ $loops -ge 0 ]; do
   mknod $INITRD_TREE/dev/loop$loops b 7 $loops
   loops=$(($loops-1))
done

echo "copying files to the rootdisk"
touch $INITRD_TREE/etc/{m,fs}tab
cp {linuxrc.S,liblinuxlive} $INITRD_TREE # symlink will be copied as original file
chmod a+x $INITRD_TREE/linuxrc.S

cp static-binaries/modprobe $INITRD_TREE/sbin
cp static-binaries/busybox $INITRD_TREE/bin
cp static-binaries/unionctl $INITRD_TREE/bin # symlink will be copied as original file
ln -s busybox $INITRD_TREE/bin/ash
ln -s busybox $INITRD_TREE/bin/sh
ln -s busybox $INITRD_TREE/bin/[

LMK="lib/modules/$KERNEL"

#necessary modules and dependency files
mkdir -p $INITRD_TREE/$LMK/kernel/fs
#mute
#cp /lib/modules/$KERNEL/unionfs.ko.gz $INITRD_TREE/$LMK/kernel/fs
#cp /lib/modules/$KERNEL/squashfs.ko.gz $INITRD_TREE/$LMK/kernel/fs
cp /lib/modules/$KERNEL/kernel/fs/unionfs/unionfs.ko $INITRD_TREE/$LMK/kernel/fs
cp /lib/modules/$KERNEL/kernel/fs/squashfs/squashfs.ko $INITRD_TREE/$LMK/kernel/fs

#copy filesystem modules, if not directly copied into kernel
rcopy_ex /$LMK/kernel/lib/zlib_inflate $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/block/loop* $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/cdrom $INITRD_TREE 2>/dev/null

#mute kokoga shusei hituyou.
rcopy_ex /$LMK/kernel/drivers/ide $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/scsi $INITRD_TREE 2>/dev/null

rcopy_ex /$LMK/kernel/fs/isofs $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/fs/fat $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/fs/vfat $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/fs/ntfs $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/fs/ext3 $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/fs/reiserfs $INITRD_TREE 2>/dev/null

# add language support for filesystems
rcopy_ex /$LMK/kernel/fs/nls/ $INITRD_TREE 2>/dev/null

#usb modules
rcopy_ex /$LMK/kernel/drivers/usb/storage $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/usb/host/ehci-hcd* $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/usb/host/ohci-hcd* $INITRD_TREE 2>/dev/null
rcopy_ex /$LMK/kernel/drivers/usb/host/uhci-hcd* $INITRD_TREE 2>/dev/null
#rcopy_ex /$LMK/kernel/drivers/usb/storage $INITRD_TREE 2>/dev/null

#disk (scsi, ide, raid, pcmcia) modules
#rcopy_ex /$LMK/kernel/drivers/scsi $INITRD_TREE
#rcopy_ex /$LMK/kernel/drivers/ide $INITRD_TREE
#rcopy_ex /$LMK/kernel/drivers/pcmcia $INITRD_TREE

echo "gzipping kernel modules"
find $INITRD_TREE -name "*.ko" | xargs -r gzip --best

echo "generating module dependency files"
depmod -b $INITRD_TREE $KERNEL

echo "creating empty image file $INITRDIMG"
dd if=/dev/zero of=$INITRDIMG bs=1024 count=10000 >/dev/null 2>/dev/null

echo "making filesystem"
mkfs -t ext2 -F -m 0 -b 1024 -i 1024 $INITRDIMG 2>/dev/null >/dev/null

echo "creating empty directory $MOUNTDIR"
rm -Rf $MOUNTDIR
mkdir $MOUNTDIR

echo "mounting $INITRDIMG to it"
mount -o loop $INITRDIMG $MOUNTDIR
if [ "$?" -ne 0 ]; then
   echo "Error mounting initrd! Not enough free loop devices?"
   exit 1
fi

echo "copying content of $INITRD_TREE to $MOUNTDIR"
rmdir $MOUNTDIR/lost+found
cp -R --preserve $INITRD_TREE/* $MOUNTDIR

echo "unmounting $MOUNTDIR"
umount $MOUNTDIR

echo "gzipping $INITRDIMG"
gzip --best $INITRDIMG

debug "deleting directory $MOUNTDIR"
rmdir $MOUNTDIR

debug "deleting directory $INITRD_TREE"
rm -Rf $INITRD_TREE

debug "$INITRDIMG.gz created"
