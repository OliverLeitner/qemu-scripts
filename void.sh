#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
NETNAME=void
HOSTNAME=${NETNAME}
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
MEM=4G
# intel render node
GVT_RENDER=/dev/dri/by-path/pci-0000:00:02.0-render
# nvidia render node
NV_RENDER=/dev/dri/by-path/pci-0000:01:00.0-render
#DP=sdl,gl=on
DP=egl-headless,rendernode=${NV_RENDER} #rendernode=/dev/dri/by-path/pci-0000:00:02.0-render
MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=off,nvdimm=off,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kvm-shadow-mem=256000000,kernel_irqchip=on
UUID="$(uuidgen)"
CPU=2,maxcpus=2,cores=2,sockets=1,threads=1
BIOS=/usr/share/OVMF/OVMF_CODE.fd
ISODIR=/applications/OS/isos
VMDIR=/virtualisation
VARS=${VMDIR}/ovmf/OVMF_VARS-${NETNAME}.fd

args=(
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    -no-user-config
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -mem-prealloc
    -global kvm-pit.lost_tick_policy=delay
    -rtc base=localtime
    -object iothread,id=iothread0
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,index=0,media=disk,if=none,format=qcow2,cache=none,aio=io_uring
    -device virtio-blk-pci,drive=drive0,iothread=iothread0
    -chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    -tpmdev emulator,id=tpm0,chardev=chrtpm
    -device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    -overcommit mem-lock=off
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0
    -device virtio-serial-pci
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -device virtio-vga-gl,edid=on
    #-vga none
    #-device qxl-vga
    #-global qxl-vga.ram_size=262144 -global qxl-vga.vram_size=262144 -global qxl-vga.vgamem_mb=256
    #-spice agent-mouse=off,image-compression=off,jpeg-wan-compression=never,gl=on,rendernode=/dev/dri/renderD128,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on
    -spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -display ${DP}
    -device virtio-serial
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
    -audiodev pa,id=snd0,server=unix:/run/user/1000/pulse/native,out.mixing-engine=off
    #-audiodev sdl,id=sdl0
    -device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    #-device hda-micro,audiodev=pa
    #-device ac97,audiodev=sdl0
    -device virtio-net-pci,mq=on,packed=on,netdev=net0,mac=${MAC}
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
    -usb
    -device usb-ehci,id=usb
    -device usb-tablet
    -monitor stdio
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
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
exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

# intel
#DRI_PRIME=pci-0000_00_02_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
# nvidia
DRI_PRIME=pci-0000_01_00_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"

exit 0
