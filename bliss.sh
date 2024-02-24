#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
SPICE_PORT=5930
MEM=4G
# intel render node
GVT_RENDER=/dev/dri/by-path/pci-0000:00:02.0-render
# nvidia render node
NV_RENDER=/dev/dri/by-path/pci-0000:01:00.0-render
NETNAME=$(basename $0 |cut -d"." -f 1)
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
#DP=sdl,gl=on
DP=egl-headless,rendernode=${NV_RENDER} #rendernode=/dev/dri/by-path/pci-0000:00:02.0-render
#DP=sdl
MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=on,memory-backend=mem1
#MTYPE=q35
ACCEL=accel=kvm #,shadow-mem=256000000
UUID="$(uuidgen)"
CPU=2,maxcpus=2,dies=1,cores=2,sockets=1,threads=1
VMDIR=/virtualisation
ISODIR=/applications/OS/isos

# some help output
CONN=$(grep -e " -spice" ${NETNAME}.sh |awk '$0 !~ /CONN/' |grep -e "addr=" |cut -d"=" -f 3 |cut -d"," -f 1)

if [[ "${CONN}" == "127.0.0.1" ]]; then
    # in case of spice tcp
    echo
    echo "connect to: spice://127.0.0.1:${SPICE_PORT}"
    echo
fi

if [[ "${CONN}" == *"spice.sock" ]]; then
    # in case of unix socket
    echo
    echo "connect to: spice+unix:///tmp/${NETNAME}/spice.sock"
    echo
fi

args=(
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    #-cpu host
    -cpu host,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -mem-prealloc
    #-global kvm-pit.lost_tick_policy=delay
    #-rtc base=localtime
    #-parallel none
    #-serial none
    -drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd"
    -drive "if=pflash,format=raw,file=/tmp/${NETNAME}/my_vars.fd"
    #-drive file=${VMDIR}/${NETNAME}.qcow2,if=virtio,cache=none,cache.direct=off,aio=io_uring #,cache=writeback,aio=io_uring
    -object iothread,id=iothread0
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,if=none,format=qcow2,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,drive=drive0,num-queues=4,iothread=iothread0
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    -overcommit mem-lock=off
    #-overcommit cpu-pm=on
    #-device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    #-object rng-random,id=objrng0,filename=/dev/urandom
    #-device virtio-rng-pci,rng=objrng0,id=rng0
    #-device virtio-serial-pci
    -device virtio-serial
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
    -device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    -audiodev pa,id=snd0,server=unix:/run/user/1000/pulse/native,out.mixing-engine=off
    #-audiodev sdl,id=sdl0
    -device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    #-device hda-micro,audiodev=pa
    #-device ac97,audiodev=sdl0
    #-vga virtio
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    -device virtio-vga-gl,edid=on
    #-spice agent-mouse=off,image-compression=off,jpeg-wan-compression=never,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on
    #-spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -spice agent-mouse=off,addr=127.0.0.1,port=${SPICE_PORT},disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never,streaming-video=off,playback-compression=off,rendernode=${NV_RENDER}
    -display ${DP}
    -chardev pty,id=charserial0
    -device isa-serial,chardev=charserial0,id=serial0
    -chardev spicevmc,id=charchannel0,name=vdagent
    #-usb
    #-device usb-ehci,id=usb
    #-device usb-tablet
    -monitor stdio
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
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

# intel
#DRI_PRIME=pci-0000_00_02_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
# nvidia
DRI_PRIME=pci-0000_01_00_0 GALLIUM_DRIVER=zink GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"

exit 0
