#!/bin/bash

gitinit() {
    [ -d $KSOURCE ] || mkdir -p $KSOURCE
    if ! git -C $KSOURCE rev-parse >/dev/null 2>&1 ; then
        echo "###start ksource git init"
        git -C $KSOURCE init
        git -C $KSOURCE remote add origin https://android.googlesource.com/kernel/msm
    fi
}

dobuild() {
    #check remote kernel version
    curl -sL "https://android.googlesource.com/kernel/msm/+/refs/tags/${ktag}/Makefile?format=TEXT" | base64 -d >remotemakefile
    if [ $? != 0 ] ; then
        echo "check remote kernel version failed, skip"
        return
    fi
    kversion=$(sed -nr 's/^VERSION = ([0-9]+)$/\1/p' remotemakefile)
    kpatchlevel=$(sed -nr 's/^PATCHLEVEL = ([0-9]+)$/\1/p' remotemakefile)
    ksublevel=$(sed -nr 's/^SUBLEVEL = ([0-9]+)$/\1/p' remotemakefile)
    rm remotemakefile
    kfullversion="$kversion.$kpatchlevel.$ksublevel"
    if ! [[ $kfullversion =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
        echo "parsing kernel version failed, skip"
        return
    fi
    
    #get last commit hash if kernel <= 4.4
    # if [ $kversion -eq 4 ] && [ $kpatchlevel -eq 4 ] || [ $kversion -eq 3 ] ; then
    #     #ktaghash=$(git -C $KSOURCE ls-remote --tags origin ${ktag} | sed -nr 's/^(.{9}).*$/\1/p')
    #     ktaghash=$(git -C $KSOURCE ls-remote --tags origin "${ktag}^{}" | sed -nr 's/^(.{11}).*$/\1/p')
    #     if [ -z $ktaghash ] ; then
    #         echo "get remote tag hash failed, skip"
    #         return
    #     fi
    #     kfullversion="${kfullversion}-g${ktaghash}"
    # fi

    echo "###$k remote kernel version: $kfullversion"

    #check if exist
    outdir=$device/$kfullversion
    if [ -d $outdir ] && [ $REBUILD != "yes" ] ; then
        echo "###$device-$kfullversion existed, skip"
        return
    fi
    echo "###start build $k"
    mkdir -p $outdir

    #fetch ksource
    echo "###start checkout source"
    git -C $KSOURCE fetch --depth 1 origin ${ktag}:${ktag}
    git -C $KSOURCE checkout ${ktag}

    #set build flags and env
    export LD_LIBRARY_PATH="$TOOLCHAIN/clang/lib64"
    export DTC_EXT="$TOOLCHAIN/dtc/dtc"
    #for 4.14 4.19
    if [ $kversion -eq 4 ] && [ $kpatchlevel -ge 14 ] ; then
        export PATH="$TOOLCHAIN/clang/bin:$TOOLCHAIN/aarch64/bin:$TOOLCHAIN/arm/bin:$PATH"
        buildflags="CC=clang LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-androideabi- NM=llvm-nm OBJCOPY=llvm-objcopy"
    fi
    #for 4.4 4.9
    if [ $kversion -eq 4 ] && [ $kpatchlevel -lt 14 ] ; then
        export PATH="$TOOLCHAIN/clang/bin:$TOOLCHAIN/aarch64/bin:$TOOLCHAIN/arm/bin:$PATH"
        buildflags="CC=clang CLANG_TRIPLE=aarch64-linux-gnu-"
    fi
    #for 3.x
    if [ $kversion -eq 3 ] ; then
        export PATH="$TOOLCHAIN/aarch64-a10/bin:$TOOLCHAIN/arm-a10/bin:$PATH"
        buildflags=""
    fi
    echo "###buildflags: $buildflags"
    echo "###path: $PATH"

    #set build command
    build="\
    make O=out \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    $buildflags \
    -C $KSOURCE
    "

    #clean output dir
    [ ! -d $KSOURCE/out ] || rm -rf $KSOURCE/out
    mkdir -p $KSOURCE/out

    #defconfig
    echo "###make ${device}_defconfig"
    $build ${device}_defconfig
    #get dirty
    echo -e "CONFIG_IP_SET=m\nCONFIG_IP_SET_HASH_NET=m\nCONFIG_IP_SET_MAX=256\nCONFIG_NETFILTER_XT_SET=m" >>$KSOURCE/out/.config
    $build olddefconfig

    #make modules_prepare
    echo "###make modules_prepare"
    $build modules_prepare
    if [ $? != 0 ] ; then
        echo "###$k make modules_prepare failed"
        rm -rf $KSOURCE/out
        return
    fi

    #make modules
    echo "###make modules"
    $build M=net/netfilter V=0 -j2
    if [ $? != 0 ] ; then
        echo "###make modules great again"
        $build M=net/netfilter V=0 -j2
    fi
    if [ $? != 0 ] ; then
        echo "###$k make modules failed"
        rm -rf $KSOURCE/out
        return
    fi

    #strip and cp ko to prebuild branch
    for ko in "$KSOURCE/out/net/netfilter/ipset/ip_set.ko" "$KSOURCE/out/net/netfilter/ipset/ip_set_hash_net.ko" "$KSOURCE/out/net/netfilter/xt_set.ko"
    do
        if ! aarch64-linux-android-strip -d $ko ;then echo "strip $ko failed" && return ;fi
        if ! cp $ko $outdir/ ;then echo "copy $ko failed" && return ;fi
    done
    #clean ouput dir and make a count
    rm -rf $KSOURCE/out
    let count++
}

##################### Main engines engaged #####################

#set targets
#    "b1c1-11.0.0_r0.28"
ktarget=(
    "redbull-11.0.0_r0.47"
    "sunfish-11.0.0_r0.45"
    "floral-11.0.0_r0.44"
    "bonito-11.0.0_r0.43"
    "wahoo-11.0.0_r0.34"
    "marlin-10.0.0_r0.23"
)

#init ksource
gitinit

#counting success build
count=0

#do build for every target
for k in "${ktarget[@]}"
do
    device=$(echo $k | cut -d "-" -f 1)
    ktag="android-$(echo $k | cut -d "-" -f 2)"
    resetpath=$PATH
    dobuild
    PATH=$resetpath
done

#push
echo "build count: $count"
if [ $count -gt 0 ] ; then
    git config user.name github-actions
    git config user.email github-actions@github.com
    git add .
    git commit -m "generated"
    git push
fi
