#!/sbin/sh

SKIPUNZIP=1

iferr() {
  if [ $? != 0 ]; then
    abort "$1"
  fi
}

kmodinstall(){
  #get device codename and kernel version
  myprod=$(getprop ro.build.product)
  mykver=$(uname -r | sed -nr 's/^([0-9]+\.[0-9]+\.[0-9]+).*$/\1/p')

  #map device codename to kernel config name
  case $myprod in
    #p5/p4a-5g
    redfin|bramble)      kname="redbull"
    ;;
    #p4a
    sunfish)             kname="sunfish"
    ;;
    #p4/p4xl
    flame|coral)         kname="floral"
    ;;
    #p3a/xl
    sargo|bonito)        kname="bonito"
    ;;
    #p3/p3xl
    blueline|crosshatch) kname="b1c1"
    ;;
    #p2/p2xl
    walleye|taimen)      kname="wahoo"
    ;;
    #p1/xl
    sailfish|marlin)     kname="marlin"
    ;;
    *) abort "$myprod not supported"
  esac

  # detect curl
  icurl="curl"
  if ! type curl >/dev/null 2>&1 ; then
    unzip -j -o "${ZIPFILE}" 'binary/curl' -d ${TMPDIR} >&2
    chmod 755 ${TMPDIR}/curl
    icurl="${TMPDIR}/curl"
  fi
  icurl="$icurl --retry 2 --connect-timeout 5 --dns-servers 1.1.1.1"

  #check if pre-compiled kmod available
  ui_print "codename: $myprod"
  ui_print "build id: $(getprop ro.build.id)"
  ui_print "kernel: $(uname -a)"
  giturl="https://github.com/emptyteeth/pixel-kmod-ipset"
  gitbranch="pre-compiled"
  $icurl -sI -o /dev/null -w "%{http_code}" ${giturl}/tree/${gitbranch}/${kname}/${mykver} | grep "200" >/dev/null 2>&1
  iferr "not available for kernel version ${mykver}"

  #download kmod
  ui_print "downloading kmod for ${myprod}-${mykver}"
  mkdir -p $kmodpath
  dcount=3
  for k in ip_set ip_set_hash_net xt_set
  do
    $icurl -sL ${giturl}/raw/${gitbranch}/${kname}/${mykver}/${k}.ko -o ${kmodpath}/${k}.ko
    iferr "download ${k}.ko failed"
    dcount=$((dcount-1))
    ui_print "${k}.ko downloaded, $dcount remaining"
  done
  set_perm_recursive $kmodpath 0 0 750 640
}

paperwork(){
  #unzip files
  unzip -j -o "${ZIPFILE}" 'post-fs-data.sh' -d $MODPATH >&2
  unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d $MODPATH >&2
  unzip -j -o "${ZIPFILE}" 'module.prop' -d $MODPATH >&2

  #set permission
  ui_print "Setting permissions"
  set_perm $MODPATH/post-fs-data.sh 0 0 750
  set_perm $MODPATH/uninstall.sh 0 0 750
  set_perm $MODPATH/module.prop 0 0 644
}

kmodload(){
  #load kmod
  ui_print "Loading kmod"
  for k in ip_set ip_set_hash_net xt_set
  do
      insmod ${kmodpath}/${k}.ko
      iferr "load ${k}.ko failed"
  done
}

####################main start####################

kmodpath="/data/pixel-kmod"

mcount=0
for k in ip_set ip_set_hash_net xt_set
do
  if [ -d /sys/module/${k} ] ; then
    ui_print "${k} loaded"
    mcount=$((mcount+1))
  fi
done

#if not loaded
if [ $mcount -eq 0 ]; then
  kmodinstall
  paperwork
  kmodload
  ui_print "all loaded, reboot is unnecessary"
#if all loaded
elif [ $mcount -eq 3 ]; then
  paperwork
  ui_print "all loaded, reboot is unnecessary"
#if partly loaded
elif [ $mcount -gt 0 ] && [ $mcount -lt 3 ] ; then
  ui_print  "seems $mcount of 3 kmod loaded, that's weird"
  ui_print  "try remove this module from magisk and reboot"
  ui_print  "then reinstall this module"
  abort
fi
