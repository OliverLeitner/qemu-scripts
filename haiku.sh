#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
NETNAME=haiku
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
HOSTNAME=${NETNAME}
MEM=4G
# intel render node
GVT_RENDER=/dev/dri/by-path/pci-0000:00:02.0-render
# nvidia render node
NV_RENDER=/dev/dri/by-path/pci-0000:01:00.0-render
#DP=sdl
#DP=sdl,gl=on,show-cursor=off
DP=egl-headless,rendernode=${NV_RENDER} #rendernode=/dev/dri/by-path/pci-0000:00:02.0-render
#DP=gtk,gl=on
#MTYPE=q35
#,memory-backend=mem1
MTYPE=q35,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=on,nvdimm=off,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kernel_irqchip=on
CPU=2,maxcpus=2,cores=2,sockets=1,threads=1
BIOS=/usr/share/OVMF/OVMF_CODE.fd
ISODIR=/applications/OS/isos
VMDIR=/virtualisation
VARS=${VMDIR}/ovmf/OVMF_VARS-${NETNAME}.fd
UUID="$(uuidgen)"

args=(
    -nodefaults
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    #-parallel none
    #-serial none
    -no-user-config
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,vmware-cpuid-freq=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    -global kvm-pit.lost_tick_policy=delay
    -mem-prealloc
    -rtc base=localtime
    -object iothread,id=iothread0
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,media=disk,if=none,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,drive=drive0,iothread=iothread0
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    -overcommit mem-lock=off
    #-device ${SHMEM}
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0,max-bytes=1024,period=1000
    #-device intel-iommu
    -device virtio-serial-pci
    -device virtio-serial
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -chardev spicevmc,id=vdagent0,name=vdagent
    -device virtserialport,chardev=vdagent0,name=com.redhat.spice.0
    -device virtio-vga-gl,edid=on
    #-device virtio-gpu-gl-pci,edid=on
    #-vga none
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    #-device vmware-svga
    #-global vmware-svga.vgamem_mb=1024
    -spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -display ${DP}
    -device virtio-net-pci,mq=on,packed=on,netdev=net0,mac=${MAC}
    # working nics: e1000 (instable), usb-net (super slow), pcnet (even slower), rtl8139, virtio-net-pci (instable)
    #-device rtl8139,netdev=net0,mac=${MAC} #,mq=on,packed=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
    #-netdev user,id=net0,ipv6=off
    #-audiodev sdl,id=snd0
    -audiodev pa,id=snd0,server=unix:/run/user/1000/pulse/native,out.mixing-engine=off
    -device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    #-audiodev sdl,id=sdl0
    #-device ac97,audiodev=sdl0
    -usb
    -device usb-tablet
    -monitor stdio
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
)

# check if the bridge is up, if not, dont let us pass here
#if [[ $(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1 }') != *tap0-${NETNAME}* ]]; then
#    echo "bridge is not running, please start bridge interface"
#    exit 1
#fi

#create tmp dir if not exists
if [ ! -d "/tmp/${NETNAME}" ]; then
    mkdir /tmp/${NETNAME}
fi

# get tpm going
#exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

# intel
#DRI_PRIME=pci-0000_00_02_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
# nvidia
DRI_PRIME=pci-0000_01_00_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"


exit 0
