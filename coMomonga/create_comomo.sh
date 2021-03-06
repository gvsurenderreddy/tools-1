#!/bin/bash

PKGLISTS_BASE=pkglists/pkglist.base
PKGLISTS_XORG=pkglists/pkglist.xorg
PKGLISTS_XFCE4=pkglists/pkglist.xfce4
PKGLISTS_GNOME=pkglists/pkglist.gnome
PKGLISTS_KDE=pkglists/pkglist.kde
PKGLISTS_OOO=pkglists/pkglist.ooo
PKGLISTS_RAILS=pkglists/pkglist.rails
PKGLISTS_PERL=pkglists/pkglist.perl
PKGLISTS_ADD=pkglists/pkglist.add
PKGLISTS_WEB=pkglists/pkglist.web
IMAGEFILE=$1
REPOBASE=$2
SCRIPTBASE=`pwd`

INSTALL_XORG=yes
INSTALL_XFCE4=no
INSTALL_GNOME=yes
INSTALL_RAILS=yes
INSTALL_PERL=yes
INSTALL_WEB=yes
INSTALL_KDE=no
INSTALL_OOO=no

XORG_LANG=ja_JP.UTF-8
XORG_SESSION=gnome
XORG_XIM=SCIM


if [ ! $# = 2 ] ; then
	echo "$0: [coMomonga Image File] [Image Mount Directory]"
	exit 1
fi

if [ ! -d $REPOBASE ]; then
	echo "Image Mount Directory: $REPOBASE not found"
	exit 1
fi

if [ ! -f $IMAGEFILE ]; then
	echo "$IMAGEFILE: file not found"
	exit 1
fi

if [ ! -f $PKGLISTS_BASE ]; then
	echo "$PKGLISTS_BASE: file not found"
	exit 1
fi

echo "Format image file"
mkfs.reiserfs -f $IMAGEFILE

echo "Mount image file"
mount -o loop,noatime -t reiserfs $IMAGEFILE $REPOBASE


echo "Making directories"
# mkdir -p $REPOBASE/dev $REPOBASE/etc  $REPOBASE/dev/pts
mkdir -p $REPOBASE/dev $REPOBASE/etc 

echo "Making /dev/console"
mknod -m 600 $REPOBASE/dev/console c 5 1

echo "Making /dev/null"
mknod -m 666 $REPOBASE/dev/null c 1 3

# echo "Makeing /dev/cobdX"
# for num in 0 1 2 3 4 5 6 7 8 9
# do
# 	mknod $REPOBASE/dev/cobd$num b 117 $num
# done

echo "Makeing /etc/udev/devices/cobdX"
mkdir -p $REPOBASE/etc/udev/devices/
for num in 0 1 2 3 4 5 6 7 8 9
do
	mknod $REPOBASE/etc/udev/devices/cobd$num b 117 $num
done

# echo "Makeing /dev/tty0"
# mknod $REPOBASE/dev/tty0 c 4 0

# echo "Makeing /dev/ttyX"
# for num in 0 1 2 3 4 5 6 7 8 9
# do
# 	mknod $REPOBASE/dev/tty$num c 4 $num
# done

# echo "Makeing /etc/udev/devices/tty0"
mknod $REPOBASE/etc/udev/devices/tty0 c 4 0

# echo "Makeing /etc/udev/devices/ttyX"
# for num in 0 1 2 3 4 5 6 7 8 9
# do
# 	mknod $REPOBASE/etc/udev/devices/tty$num c 4 $num
# done

echo "Makeing /etc/udev/devices/ptmx"
mknod -m 666 $REPOBASE/etc/udev/devices/ptmx c 5 2

# echo "Makeing /dev/pts/X"
# for num in 0 1 2 3 4 5 6 7 8 9
# do
#         mknod $REPOBASE/dev/pts/$num c 136 $num
# done

echo "Makeing /etc/udev/devices/random"
mknod -m 644 $REPOBASE/etc/udev/devices/random c 1 8

echo "Makeing /etc/udev/devices/urandom"
mknod -m 644 $REPOBASE/etc/udev/devices/urandom c 1 9

echo "Makeing /etc/udev/devices/urandom"
# chown -v root:tty $REPOBASE/etc/udev/devices/{console,ptmx,tty*}
chown -v root:tty $REPOBASE/etc/udev/devices/{ptmx,tty*}
# chown -v root:tty $REPOBASE/etc/udev/devices/ptmx

echo "Creating /etc/fstab"
cat << EOF > $REPOBASE/etc/fstab
/dev/cobd0  /               reiserfs        defaults,noatime    1 1
/dev/cobd1  swap            swap            defaults            0 0
none        /dev/pts        devpts          gid=5,mode=620      0 0
sysfs       /sys            sysfs           defaults            0 0
none        /proc           proc            defaults            0 0
EOF

echo "Creating /etc/hosts"
cat << EOF > $REPOBASE/etc/hosts
127.0.0.1       localhost.localdomain   localhost coMomonga
EOF

touch $REPOBASE/etc/resolv.conf

echo "Mounting /proc"
mkdir -p $REPOBASE/proc
mount none -t proc $REPOBASE/proc

echo "Mounting /sys"
mkdir -p $REPOBASE/sys
mount none -t sysfs $REPOBASE/sys

echo "Copying yum setting"
cp -a /etc/yum.repos.d $REPOBASE/etc/yum.repos.d.tmp
perl -npe 's/exclude.*\n//' /etc/yum.conf > $REPOBASE/etc/yum.conf.tmp
echo 'reposdir=/etc/yum.repos.d.tmp' >> $REPOBASE/etc/yum.conf.tmp

echo "Installing base package"
yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_BASE`

if [ x$INSTALL_XORG = "xyes" -a -f $PKGLISTS_XORG ]; then
	echo "Installing Xorg package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_XORG`
fi

if [ x$INSTALL_XFCE4 = "xyes" -a -f $PKGLISTS_XFCE4 ]; then
	echo "Installing XFce4 package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_XFCE4`
fi

if [ x$INSTALL_GNOME = "xyes" -a -f $PKGLISTS_GNOME ]; then
	echo "Installing GNOME package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_GNOME`
fi

if [ x$INSTALL_KDE = "xyes" -a -f $PKGLISTS_KDE ]; then
	echo "Installing KDE package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_KDE`
fi

if [ x$INSTALL_OOO = "xyes" -a -f $PKGLISTS_OOO ]; then
	echo "Installing OpenOffice.org package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_OOO`
fi

if [ x$INSTALL_RAILS = "xyes" -a -f $PKGLISTS_RAILS ]; then
	echo "Installing Ruby on Rails package"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_RAILS`
fi

if [ x$INSTALL_PERL = "xyes" -a -f $PKGLISTS_PERL ]; then
	echo "Installing Perl Packages"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_PERL`
fi

if [ -f $PKGLISTS_ADD ]; then
	echo "Installing additional packages"
	yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
	`cat $PKGLISTS_ADD`
fi

if [ -f $PKGLISTS_WEB ]; then
        echo "Installing web packages"
        yum -c $REPOBASE/etc/yum.conf.tmp -y --installroot=$REPOBASE install \
        `cat $PKGLISTS_WEB`
fi

echo "Creating Network settings"
cat << EOF > $REPOBASE/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=coMomonga
EOF
# HOSTNAME=livecd
# EOF
# cat << EOF > $REPOBASE/etc/sysconfig/network-scripts/ifcfg-eth0
# DEVICE=eth0
# BOOTPROTO=dhcp
# ONBOOT=yes
# TYPE=Ethernet
# EOF


if [ x$INSTALL_XORG = "xyes" -a -f $PKGLISTS_XORG ]; then
echo "Creating Xorg configs"
cat << EOF > $REPOBASE/etc/sysconfig/xinit-lang
$XORG_LANG
EOF
cat << EOF > $REPOBASE/etc/sysconfig/xinit-session
$XORG_SESSION
EOF
cat << EOF > $REPOBASE/etc/sysconfig/xinit-xim
$XORG_XIM
EOF
fi

echo "Creating System Font setting"
echo 'SYSFONT="latarcyrheb-sun16"' >> $REPOBASE/etc/sysconfig/i18n

echo "Adding to /etc/sysconfig/authconfig"
cat << EOF >> $REPOBASE/etc/sysconfig/authconfig
USECRACKLIB=yes
USEMD5=yes
USESHADOW=yes
EOF

echo "Adding to /etc/sysconfig/keyboard"
cat << EOF >> $REPOBASE/etc/sysconfig/keyboard
KEYBOARDTYPE="pc"
KEYTABLE="jp106"
EOF

echo "Adding to /etc/sysconfig/clock"
cat << EOF >> $REPOBASE/etc/sysconfig/clock
ZONE="Asia/Tokyo"
UTC=false
ARC=false
EOF


echo "Creating /etc/localtime"
cp $REPOBASE/usr/share/zoneinfo/Japan $REPOBASE/etc/localtime

cp xorg.conf $REPOBASE/etc/X11/

# echo "Modifying /etc/init.d/halt, /etc/init.d/netfs"
# cp shutdown.patch $REPOBASE/tmp
# (
# 	cd $REPOBASE
# 	patch -p0 < $REPOBASE/tmp/shutdown.patch
# 	rm -f $REPOBASE/tmp/shutdown.patch
# )
if [ x$INSTALL_XORG = "xyes" -a -f $PKGLISTS_XORG ]; then
	echo "Setting default runlevel to 5"
	mv $REPOBASE/etc/inittab $REPOBASE/etc/inittab.rpmorig
	perl -npe 's/id:3:initdefault:/id:5:initdefault:/' $REPOBASE/etc/inittab.rpmorig \
		> $REPOBASE/etc/inittab
	chmod 755 $REPOBASE/etc/inittab
fi
# 
# echo "Adding to /etc/rc.local"
# cat << EOF >> $REPOBASE/etc/rc.local
# if [ \`/sbin/runlevel | awk '{ print \$2 }'\` == "5" ]; then
#         LANG=ja_JP.EUC-JP /usr/bin/system-config-display
# fi
# /usr/bin/system-config-keyboard --text
# EOF

if [ x$INSTALL_XORG = "xyes" -a -f $PKGLISTS_XORG ]; then

echo "Modifying /etc/X11/gdm/custom.conf"
pushd $REPOBASE/etc/X11/gdm/
patch -p1 < $SCRIPTBASE/gdm_custom.conf-xdmcp.patch
popd

# echo "Modifying /usr/share/X11/app-defaults/XScreenSaver"
# pushd $REPOBASE/usr/share/X11/app-defaults/
# patch -p1 < $SCRIPTBASE/xscreensaver-no_stderr.patch
# popd

echo "Modifying /etc/X11/fs/config"
pushd $REPOBASE/etc/X11/fs
patch -p1 < $SCRIPTBASE/xfs-tcp_listen.patch
popd

fi

# echo "Create account and setting password"
# echo momonga | chroot $REPOBASE passwd --stdin root
# chroot $REPOBASE /usr/sbin/useradd momonga
# echo momonga | chroot $REPOBASE passwd --stdin momonga
# echo 'momonga ALL=(ALL) NOPASSWD: ALL' >> $REPOBASE/etc/sudoers

echo "Disable unused startup daemons"
/usr/sbin/chroot $REPOBASE chkconfig acpid off
/usr/sbin/chroot $REPOBASE chkconfig apmd off
/usr/sbin/chroot $REPOBASE chkconfig autofs off
/usr/sbin/chroot $REPOBASE chkconfig avahi-daemon off
/usr/sbin/chroot $REPOBASE chkconfig firstboot off
/usr/sbin/chroot $REPOBASE chkconfig smartd off
/usr/sbin/chroot $REPOBASE chkconfig cpuspeed off
/usr/sbin/chroot $REPOBASE chkconfig iptables off
/usr/sbin/chroot $REPOBASE chkconfig irqbalance off
/usr/sbin/chroot $REPOBASE chkconfig lm_sensors off
/usr/sbin/chroot $REPOBASE chkconfig kudzu off
/usr/sbin/chroot $REPOBASE chkconfig mcstrans off
/usr/sbin/chroot $REPOBASE chkconfig mdmonitor off
/usr/sbin/chroot $REPOBASE chkconfig pcmcia off
/usr/sbin/chroot $REPOBASE chkconfig postfix off
/usr/sbin/chroot $REPOBASE chkconfig restorecond off
/usr/sbin/chroot $REPOBASE chkconfig xfs off


# echo "Copying installer staff"
# if [ -d "inst_dir" ]; then
#     cp -a inst_dir $REPOBASE/inst_dir
#     find $REPOBASE/inst_dir -name ".svn" -exec rm -rf {} \; 2> /dev/null
# else
#     mkdir $REPOBASE/inst_dir
# fi
# mkdir $REPOBASE/install

echo "Create /.unconfigure"
touch $REPOBASE/.unconfigured

echo "Create /etc/modprobe.conf"
touch $REPOBASE/etc/modprobe.conf

echo "Create /etc/modules.conf"
touch $REPOBASE/etc/modules.conf

echo "Extract coLinux module files"
tar zxvf vmlinux-modules.tar.gz -C $REPOBASE


echo "Cleaning up"
umount $REPOBASE/proc
umount $REPOBASE/sys
rm -rfv $REPOBASE/home/*
rm -fv $REPOBASE/etc/yum.conf.tmp
rm -rf $REPOBASE/etc/yum.repos.d.tmp
find $REPOBASE -name "*.rpmorig" -exec rm -fv {} \;

echo "Fill Zero Area"
echo "(dd if=dev/zero of=hoge.img)"
dd if=/dev/zero of=$REPOBASE/hoge.img bs=1M
rm -rf $REPOBASE/hoge.img

umount $REPOBASE

echo "Done!"
