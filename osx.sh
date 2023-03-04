#!/usr/bin/env bash

# Special thanks to:
# https://github.com/Leoyzen/KVM-Opencore
# https://github.com/thenickdude/KVM-Opencore/
# https://github.com/qemu/qemu/blob/master/docs/usb2.txt
#
# qemu-img create -f qcow2 mac_hdd_ng.img 128G
#
# echo 1 > /sys/module/kvm/parameters/ignore_msrs (this is required)

############################################################################
# NOTE: Tweak the "MY_OPTIONS" line in case you are having booting problems!
############################################################################

#MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890"
MY_OPTIONS="kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890"

REPO_PATH="/storage/git/OSX-KVM"
OVMF_DIR="/storage/git/OSX-KVM"

BOOT_BIN=/usr/bin/qemu-system-x86_64
NETNAME=osx
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
HOSTNAME=${NETNAME}
MEM=8G
DP=sdl,gl=on
#SHMEM=ivshmem-plain,memdev=hostmem
#MTYPE=pc
MTYPE=q35
#MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=on,memory-backend=mem1
#MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=on
#ACCEL=kvm-shadow-mem=256000000
UUID="$(uuidgen)"
CPU=2,maxcpus=2,dies=1,cores=2,sockets=1,threads=1
VMDIR=/virtualisation

# shellcheck disable=SC2054
args=(
  -uuid ${UUID}
  -name ${NETNAME},process=${NETNAME}
  -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
  -parallel none
  -serial none
  -enable-kvm
  -m ${MEM}
  -cpu host,${MY_OPTIONS}
  #-cpu host
  -machine ${MTYPE} #,${ACCEL}
  #-machine ${MTYPE}
  #-mem-prealloc
  -rtc base=localtime
  #-object rng-random,id=objrng0,filename=/dev/urandom
  #-device virtio-rng-pci,rng=objrng0,id=rng0
  #-device virtio-serial-pci
  #-chardev pty,id=charserial0
  #-device isa-serial,chardev=charserial0,id=serial0
  -device ich9-intel-hda -device hda-duplex
  #-usb -device usb-kbd -device virtio-tablet
  #-usb -device usb-ehci,id=usb -device usb-kbd -device usb-tablet
  -usb -device usb-kbd -device usb-tablet
  #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
  #-tpmdev emulator,id=tpm0,chardev=chrtpm
  #-device tpm-crb,tpmdev=tpm0
  -smp ${CPU}
  #-device nec-usb-xhci,id=xhci
  #-global nec-usb-xhci.msi=off
  # -device usb-host,vendorid=0x8086,productid=0x0808  # 2 USD USB Sound Card
  # -device usb-host,vendorid=0x1b3f,productid=0x2008  # Another 2 USD USB Sound Card
  -device isa-applesmc,osk="$(cat osxkey.txt)"
  -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$REPO_PATH/OVMF_VARS-1024x768.fd"
  #-smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}" \
  -device ich9-ahci,id=sata
  -drive id=OpenCoreBoot,index=0,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
  -device ide-hd,bus=sata.2,drive=OpenCoreBoot
  -device ide-hd,bus=sata.3,drive=InstallMedia
  -drive id=InstallMedia,index=2,if=none,file="$REPO_PATH/BaseSystem.Big.Sur.img",format=raw
  -drive id=MacHDD,index=1,media=disk,if=virtio,file="${VMDIR}/osx.qcow2",format=qcow2,cache=writeback,aio=io_uring
  #-object memory-backend-memfd,id=mem1,size=${MEM},share=on
  #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
  #-overcommit mem-lock=off
  #-device ${SHMEM}
  #-device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
  -device virtio-net-pci,mq=on,packed=on,netdev=net0,mac=${MAC}
  -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
  -monitor stdio
  #-vga vmware
  -device virtio-vga-gl,xres=1920,yres=1080 #,max_hostmem=131072
  -vga none
  # to have qxl, disable above two lines and enable the next one
  #-vga qxl -global qxl-vga.ram_size=262144 -global qxl-vga.vram_size=262144 -global qxl-vga.vgamem_mb=256
  #-device qxl,id=video1,vram_size=131072
  -display ${DP}
  # to use spice, disable the above display and use the below 4 lines up until sandbox...
  #-spice port=5920,disable-ticketing
  #-device virtio-serial
  #-chardev spicevmc,id=vdagent,debug=0,name=vdagent
  #-device virtserialport,chardev=vdagent,name=com.redhat.spice.0
  #-spice port=5920,addr=127.0.0.1,disable-ticketing=on,image-compression=off,seamless-migration=on
  #-spice unix,addr=/run/user/1000/spice.sock,disable-ticketing=on
  #-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
  -k de
)

# check if the bridge is up, if not, dont let us pass here
if [[ $(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1 }') != *tap0-${NETNAME}* ]]; then
    echo "bridge is not running, please start bridge interface"
    exit 1
fi

#create tmp dir if not exists
if [ ! -d "/tmp/${NETNAME}" ]; then
    mkdir /tmp/${NETNAME}
fi

# get tpm going
#exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &


GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"

#close up script
exit 0
