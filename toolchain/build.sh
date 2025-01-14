#!/bin/sh

PREFIX=$HOME/riscv-gcc
TARGET=riscv-elf

export PATH=$PREFIX/bin:$PATH

BINUTILS_VERSION=2.37
GCC_VERSION=11.2.0
NEWLIB_VERSION=4.1.0

set -e

rm -rf build-binutils binutils-${BINUTILS_VERSION}
rm -rf build-gcc gcc-${GCC_VERSION}
rm -rf build-newlib newlib-${NEWLIB_VERSION}

tar xvf binutils-${BINUTILS_VERSION}.tar.xz
patch -p0 -i binutils.patch
mkdir build-binutils
cd build-binutils
../binutils-2.37/configure --prefix=$HOME/riscv-gcc --target=riscv-elf \
    --with-sysroot --disable-nls --disable-werror
make
make install
cd ..

tar xvf gcc-${GCC_VERSION}.tar.xz
mkdir build-gcc
cd build-gcc
../gcc-11.2.0/configure --target=riscv-elf --prefix=$HOME/riscv-gcc \
    --disable-nls --enable-languages=c,c++ --without-headers \
    --with-abi=ilp32 --with-arch=rv32im
make all-gcc all-target-libgcc
make install-gcc install-target-libgcc
cd ..

tar xvf newlib-${NEWLIB_VERSION}.tar.gz
mkdir build-newlib
cd build-newlib
../newlib-4.1.0/configure --prefix=$HOME/riscv-gcc --target=riscv-elf
make
make install
cd ..
