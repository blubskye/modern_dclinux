#!/bin/bash

# set DEBUG > 0 to see all of the gritty details
DEBUG=0

SOURCEDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=$SOURCEDIR/2006-02-07.1
TARGET=sh4-linux
PREFIX=$BASEDIR/chroot
PATH=$PATH:$PREFIX/bin
INITRD=$BASEDIR/initrd

if [ $DEBUG -gt 0 ]; then
	BUILD_OUTPUT=/dev/stdout
	CONSOLE_OUTPUT=/dev/null
else
	BUILD_OUTPUT=$SOURCEDIR/build.log
	CONSOLE_OUTPUT=/dev/stdout
fi

rm -f $SOURCEDIR/build.log

mkdir -p $PREFIX

cd $BASEDIR

# binutils
do_binutils() {
	echo -n "Building binutils..." > $CONSOLE_OUTPUT

	(
	tar xvzf $SOURCEDIR/binutils-2.11.2.tar.gz
	patch -p0 < $SOURCEDIR/binutils-2.11.2-sh-linux.diff
	mkdir -p build-binutils && cd build-binutils
	CC=/usr/bin/gcc32 ../binutils-2.11.2/configure --target=$TARGET \
		--prefix=$PREFIX
	make all install
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# bootstrap gcc
do_bootstrap_gcc() {
	echo -n "Building bootstrap gcc..." > $CONSOLE_OUTPUT

	(
	tar xvzf $SOURCEDIR/gcc-3.0.1.tar.gz
	patch -p0 < $SOURCEDIR/gcc-3.0.1-sh-linux.diff
	mkdir -p build-gcc && cd build-gcc
	CC=/usr/bin/gcc32 ../gcc-3.0.1/configure --target=$TARGET \
		--prefix=$PREFIX --without-headers --with-newlib \
		--disable-shared --enable-languages=c
	make all-gcc install-gcc
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# kernel configuration
do_kernel_config() {
	echo -n "Building kernel configuration..." > $CONSOLE_OUTPUT

	(
	tar xvzf $SOURCEDIR/kernel-sh-linux-dreamcast.tar.gz
	patch -p0 < $SOURCEDIR/kernel-sh-linux-dreamcast.diff
	cd kernel
	make ARCH=sh CROSS_COMPILE=sh4-linux- oldconfig
	make dep
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# glibc
do_glibc() {
	echo -n "Building glibc..." > $CONSOLE_OUTPUT

	(
	tar xvzf $SOURCEDIR/glibc-2.2.4.tar.gz
	patch -p0 < $SOURCEDIR/glibc-2.2.4-sh-linux.diff
	mkdir -p build-glibc && cd build-glibc

	mkdir -p $PREFIX/$TARGET/include
	cp -r ../kernel/include/linux ${PREFIX}/$TARGET/include
	cp -r ../kernel/include/asm-sh ${PREFIX}/$TARGET/include/asm

	CC=sh4-linux-gcc ../glibc-2.2.4/configure --host=$TARGET \
		--prefix=$PREFIX --disable-debug --disable-profile \
		--disable-sanity-checks --with-headers=$PREFIX/$TARGET/include

	make
	touch iconv/iconv_prog login/pt_chown
	make install_root=${PREFIX}/$TARGET prefix="" install
	echo "GROUP ( libc.so.6 libc_nonshared.a )" > $PREFIX/$TARGET/lib/libc.so
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# full gcc
do_full_gcc() {
	echo -n "Building full gcc..." > $CONSOLE_OUTPUT

	(
	mkdir -p build-gcc2 && cd build-gcc2
	CC=/usr/bin/gcc32 ../gcc-3.0.1/configure --target=$TARGET \
		--prefix=$PREFIX --enable-languages=c,c++
	make all install
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# kernel
do_kernel() {
	echo -n "Building kernel..." > $CONSOLE_OUTPUT

	(
	cd kernel
	make ARCH=sh CROSS_COMPILE=sh4-linux- zImage
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

# busybox
do_busybox() {
	echo -n "Building busybox..." > $CONSOLE_OUTPUT

	(
	mkdir -p $INITRD
	tar xvzf $SOURCEDIR/busybox-0.60.1.tar.gz
 	patch -p0 < busybox-0.60.1-sh-linux.diff
	cd busybox-0.60.1
	make CROSS=sh4-linux- DOSTATIC=true \
		CFLAGS_EXTRA="-I $PREFIX/$TARGET/include" PREFIX=$INITRD \
		clean all install
	mkdir -p $INITRD/dev
	sudo mknod $INITRD/dev/console c 5 1
	cd ..
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

do_initrd() {
	echo -n "Building initrd..." > $CONSOLE_OUTPUT

	(
	rm -rf $BASEDIR/initrd.dir
	rm -f $BASEDIR/initrd.bin
	rm -f $BASEDIR/initrd.img
	dd if=/dev/zero of=initrd.img bs=1k count=4096
	mke2fs -F -vm0 initrd.img
	mkdir -p initrd.dir
	sudo mount -o loop initrd.img initrd.dir
	sudo tar -C $INITRD -cf - . | sudo tar -C initrd.dir -xvf -
#	sudo (cd $INITRD ; tar cf - .) | (cd initrd.dir ; tar xvf -)
	sudo umount initrd.dir
	gzip -c -9 initrd.img > initrd.bin
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

do_bootloader() {
	echo -n "Building bootloader..." > $CONSOLE_OUTPUT

	(
	tar xvzf $SOURCEDIR/sh-boot-20010831-1455.tar.gz
	patch -p0 < $SOURCEDIR/sh-boot-20010831-1455.diff
	cd sh-boot/tools/dreamcast
	cp ../../../kernel/arch/sh/boot/zImage ./zImage.bin
	cp ../../../initrd.bin .
	make scramble kernel-boot.bin
	cd $BASEDIR
	) >> $BUILD_OUTPUT 2>&1

	echo "done." > $CONSOLE_OUTPUT
}

usage() {
	echo "Usage: ./bootstrap.sh [all|binutils|bs_gcc|kconfig|glibc|full_gcc|kernel|busybox|initrd|bootloader]"
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

case "$1" in
	all)
		rm -rf $BASEDIR
		mkdir -p $PREFIX
		cd $BASEDIR
		do_binutils
		do_bootstrap_gcc
		do_kernel_config
		do_glibc
		do_full_gcc
		do_kernel
		do_busybox
		do_initrd
		do_bootloader
		;;
	binutils)
		do_binutils
		;;
	bs_gcc)
		do_bootstrap_gcc
		;;
	kconfig)
		do_kernel_config
		;;
	glibc)
		do_glibc
		;;
	full_gcc)
		do_full_gcc
		;;
	kernel)
		do_kernel
		;;
	busybox)
		do_busybox
		;;
	initrd)
		do_initrd
		;;
	bootloader)
		do_bootloader
		;;
	*)
		usage
esac
