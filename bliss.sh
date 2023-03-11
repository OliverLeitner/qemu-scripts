#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
NETNAME=bliss
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
HOSTNAME=${NETNAME}
MEM=8G
DP=sdl,gl=on
#DP=sdl
MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=on,memory-backend=mem1
#MTYPE=q35
#ACCEL=kvm-shadow-mem=256000000
UUID="$(uuidgen)"
CPU=2,maxcpus=2,dies=1,cores=2,sockets=1,threads=1
VMDIR=/virtualisation
ISODIR=/applications/OS/isos

args=(
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    -cpu host,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -rtc base=localtime
    -parallel none
    -serial none
    -drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd"
    -drive "if=pflash,format=raw,file=/tmp/${NETNAME}/my_vars.fd"
    -drive file=${VMDIR}/${NETNAME}.qcow2,if=virtio #,cache=writeback,aio=io_uring
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -machine ${MTYPE} #,${ACCEL}
    #-overcommit mem-lock=off
    #-device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    #-object rng-random,id=objrng0,filename=/dev/urandom
    #-device virtio-rng-pci,rng=objrng0,id=rng0
    #-device virtio-serial-pci
    -device virtio-vga-gl,xres=1920,yres=1080
    #-device virtio-vga,xres=1920,yres=1080
    #-device virtio-net-pci,mq=on,packed=on,netdev=net0,mac=${MAC}
    -device e1000,netdev=net0,mac=${MAC}
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
    -device ich9-intel-hda -device hda-duplex
    #-device ac97
    #-vga virtio
    -display ${DP}
    #-chardev pty,id=charserial0
    #-device isa-serial,chardev=charserial0,id=serial0
    #-chardev spicevmc,id=charchannel0,name=vdagent
    #-usb
    #-device usb-ehci,id=usb
    #-device usb-tablet
    -monitor stdio
    #-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
)

#create tmp dir if not exists
if [ ! -d "/tmp/${NETNAME}" ]; then
    mkdir /tmp/${NETNAME}
fi

#create myvars if not exists
if [ ! -f "/tmp/${NETNAME}/my_vars.fd" ]; then
    cp /usr/share/OVMF/OVMF_VARS.fd /tmp/${NETNAME}/my_vars.fd
fi

# check if the bridge is up, if not, dont let us pass here
if [[ $(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1 }') != *tap0-${NETNAME}* ]]; then
    echo "bridge is not running, please start bridge interface"
    exit 1
fi

# get tpm going
#exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"

exit 0
