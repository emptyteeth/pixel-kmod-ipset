#!/system/bin/sh

kmodpath="/data/pixel-kmod"

#delete ko file
for k in ip_set_hash_net xt_set ip_set
do
    rm ${kmodpath}/${k}.ko
done

#delete empty dir
rmdir ${kmodpath} --ignore-fail-on-non-empty
