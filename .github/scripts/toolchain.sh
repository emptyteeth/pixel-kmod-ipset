#!/bin/bash

mkdir -p $TOOLCHAIN/{aarch64,arm,clang,dtc,aarch64-a10,arm-a10}

curl -sL \
https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/heads/android11-release.tar.gz | \
tar -xz -C $TOOLCHAIN/aarch64

curl -sL \
https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/heads/android11-release.tar.gz | \
tar -xz -C $TOOLCHAIN/arm

curl -sL \
https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android11-release/clang-r383902.tar.gz | \
tar -xz -C $TOOLCHAIN/clang

curl -sL \
https://android.googlesource.com/platform/prebuilts/misc/+archive/refs/heads/master/linux-x86/dtc.tar.gz | \
tar -xz -C $TOOLCHAIN/dtc

curl -sL \
https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/heads/android10-release.tar.gz | \
tar -xz -C $TOOLCHAIN/aarch64-a10

curl -sL \
https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/heads/android10-release.tar.gz | \
tar -xz -C $TOOLCHAIN/arm-a10
