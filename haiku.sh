#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
NETNAME=haiku
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
HOSTNAME=${NETNAME}
MEM=8G
#DP=sdl
DP=sdl,gl=on
MTYPE=q35
#,memory-backend=mem1
#MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=off,nvdimm=off,hmat=on,memory-backend=mem1
ACCEL=accel=kvm
CPU=2,maxcpus=2,cores=2,sockets=1,threads=1
BIOS=/usr/share/OVMF/OVMF_CODE.fd
ISODIR=/applications/OS/isos
VMDIR=/virtualisation
VARS=${VMDIR}/ovmf/OVMF_VARS-${NETNAME}.fd
UUID="$(uuidgen)"

args=(
    #-nodefaults
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    -parallel none
    -serial none
    #-no-user-config
    #-cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on
    -cpu core2duo
    -smp ${CPU}
    -m ${MEM}
    #-mem-prealloc
    #-rtc base=localtime
    #-drive file=${ISODIR}/haiku/haiku-master-hrev56747-x86_64-anyboot.iso,index=0,media=cdrom
    -drive file=${VMDIR}/${NETNAME}.qcow2,index=0,media=disk #,if=virtio #,cache=writeback,aio=io_uring
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -enable-kvm
    #-object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -machine ${MTYPE} #,${ACCEL}
    #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    #-overcommit mem-lock=off
    #-device ${SHMEM}
    #-device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    #-object rng-random,id=objrng0,filename=/dev/urandom
    #-device virtio-rng-pci,rng=objrng0,id=rng0
    #-device virtio-serial-pci
    #-chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    #-device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    #-chardev spicevmc,id=vdagent0,name=vdagent
    #-device virtserialport,chardev=vdagent0,name=com.redhat.spice.0
    -device virtio-vga-gl,xres=1920,yres=1080
    #-device virtio-vga,xres=1920,yres=1080
    -vga none
    #-vga qxl -global qxl-vga.ram_size=1048576 -global qxl-vga.vram_size=1048576 -global qxl-vga.vgamem_mb=1024
    #-vga vmware
    -display ${DP}
    #-device virtio-net-pci,mq=on,packed=on,netdev=net0,mac=${MAC}
    -device e1000,netdev=net0,mac=${MAC}
    #-device virtio-net-pci,netdev=net0
    #-netdev user,id=net0
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
    #-device ich9-intel-hda -device hda-duplex
    -device ac97
    -usb
    -device usb-tablet
    -monitor stdio
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

exit 0
