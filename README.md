# pixel-kmod-ipset

Install ipset kernel module for pixel phones via magisk

## target device

All pixel phones with latest stock kernel  
pixel1/xl and pixel2/xl may not work right now

## build

github action build script and ko files are located in `pre-compiled` branch

## brief of the installation script

1. check if already loaded
2. check the device model and kernel version
3. download the kmods for current model from prebuilt branch if they are available
4. load the kmods into kernel by `insmod`
5. install a `post-fs-data` script to load the kmods on boot

## check if works

A successful installation implies it worked, you can double check for that by running `su` => `lsmod` to see if `ip_set` `ip_set_hash_net` `xt_set` shows up.

## after system update

reinstall this module

## magisk

[Magisk](https://github.com/topjohnwu/Magisk/) is a suite of open source tools for customizing Android, supporting devices higher than Android 4.2. It covers fundamental parts of Android customization: root, boot scripts, SELinux patches, AVB2.0 / dm-verity / forceencrypt removals etc.
