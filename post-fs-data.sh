#!/system/bin/sh

#MODDIR=${0%/*}
kmodpath="/data/pixel-kmod"

mykver=$(uname -r | sed -nr 's/^([0-9]+\.[0-9]+\.[0-9]+).*$/\1/p')
for k in ip_set ip_set_hash_net xt_set
do
  kmodver=$(modinfo ${kmodpath}/${k}.ko | sed -nr 's/^vermagic.*([0-9]+\.[0-9]+\.[0-9]+).*$/\1/p')
  #load the kmod if kernel version matched
  if [ $kmodver != $mykver ] ; then echo "${k}.ko version mismatched" >&2 && exit 1 ;fi
  if ! insmod ${kmodpath}/${k}.ko ;then echo "load ${k}.ko failed" >&2 && exit 1 ;fi
done
