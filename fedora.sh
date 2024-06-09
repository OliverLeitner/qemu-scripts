#!/bin/bash
# start cmd: ./vm.sh <nvidia|intel> <x11|wayland> [recovery]

# including help function library
source "./help.sh"

# commandline parameters
GPU_MODE=$1
GFX_BACKEND=$2
RECOVERY_MODE=$3

# ---------------- settings start ------------------
BOOT_BIN=/usr/bin/qemu-system-x86_64
MEM=4G
SPICE_PORT=6060
# intel render node
GVT_RENDER=/dev/dri/by-path/pci-0000:00:02.0-render
# nvidia render node
RENDER=/dev/dri/by-path/pci-0000:01:00.0-render
if [[ ${GPU_MODE} == *"intel"* ]]; then
    RENDER=${GVT_RENDER}
fi
NETNAME=$(basename $0 |cut -d"." -f 1)
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
SPICE_MODE=agent-mouse=on,addr=127.0.0.1,port=${SPICE_PORT},disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never,streaming-video=off,playback-compression=off,rendernode=${RENDER}
#DP=sdl,gl=on
DP=egl-headless,rendernode=${RENDER}
#SHMEM=ivshmem-plain,memdev=hostmem
MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=off,nvdimm=on,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kvm-shadow-mem=256000000
UUID="$(uuidgen)"
CPU=2,maxcpus=2,cores=2,sockets=1,threads=1
BIOS=/usr/share/OVMF/OVMF_CODE.fd
# path to the operating system iso
ISODIR=/data/isos/os
# path to the vm image
VMDIR=/virtualisation
# path to our recovery iso
RECOVERYISO=/data/isos/systemrescue-11.01-amd64.iso
# ---------------- settings end ------------------

# lets have some commandline help
case ${GPU_MODE} in
    help|--help|-h|"")
        help_vm
        exit 1
    ;;
esac

# preparing the correct host sound server
# defaults to pulseaudio
AUDIO_SERVER=pa,id=snd0,server=unix:/run/user/1000/pulse/native,out.mixing-engine=off
if [[ $(pactl info | grep "PipeWire") != "" ]]; then
    AUDIO_SERVER=pipewire,id=snd0
fi

RECOVERYINFO=
if [[ ${RECOVERY_MODE} == *"recovery"* ]]; then
    RECOVERYINFO="-boot order=d,menu=on,strict=on,splash-time=30 -drive id=drive1,file=${RECOVERYISO},index=1,media=cdrom"
fi

# output the connection string for help
CONN=$(echo ${SPICE_MODE} |grep -e 'addr=' |cut -d"=" -f 3 |cut -d"," -f 1)

# if we are using spice, we listen on localhost, you can still setup a remote conn via ssh tunneling
if [[ "${CONN}" == "127.0.0.1" ]]; then
    # in case of spice tcp
    echo
    echo "connect to: spice://127.0.0.1:${SPICE_PORT}"
    echo
fi

# if we are on a unix socket, you can still forward via ssh, basically both option including the above
# work for remote access if forwarded, i prefer a vpn solution rather than ssh though
if [[ "${CONN}" == *"spice.sock" ]]; then
    # in case of unix socket
    echo
    echo "connect to: spice+unix:///tmp/${NETNAME}/spice.sock"
    echo
fi

args=(
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME},debug-threads=on
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    -no-user-config
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off,+aes,+ssse3,+sse4.2,+avx,+avx2,check
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -mem-prealloc
    #-global kvm-pit.lost_tick_policy=delay
    #-rtc base=localtime
    -object iothread,id=iothread0
    # recovery mode
    ${RECOVERYINFO}
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,index=0,media=disk,if=none,format=qcow2,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,id=blk0,drive=drive0,num-queues=4,iothread=iothread0
    -chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    -tpmdev emulator,id=tpm0,chardev=chrtpm
    -device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    -overcommit mem-lock=off
    #-overcommit cpu-pm=on
    #-device ${SHMEM}
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0
    -device intel-iommu
    -device virtio-serial-pci
    -device virtio-serial
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
    -chardev pty,id=charserial0
    -device isa-serial,chardev=charserial0,id=serial0
    -chardev spicevmc,id=charchannel0,name=vdagent
    # usb redirect
    #-readconfig /etc/qemu/ich9-ehci-uhci.cfg
    -chardev spicevmc,name=usbredir,id=usbredirchardev1
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev2
    -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev3
    -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3,debug=0
    -device virtio-vga-gl,edid=on,xres=1920,yres=1080
    #-vga none
    #-device qxl-vga
    #-global qxl-vga.ram_size=262144 -global qxl-vga.vram_size=262144 -global qxl-vga.vgamem_mb=256
    #-spice agent-mouse=off,image-compression=off,jpeg-wan-compression=never,gl=on,rendernode=/dev/dri/renderD128,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on
    #-spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -spice ${SPICE_MODE}
    -display ${DP}
    -device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0,vhost=off,poll-us=50000
    #-netdev type=vhost-vdpa,vhostdev=/dev/vhost-vdpa-0,id=net0
    -audiodev ${AUDIO_SERVER}
    #-audiodev sdl,id=sdl0
    #-device ac97,audiodev=pa
    -device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    #-device hda-micro,audiodev=pa
    -usb
    -device usb-ehci,id=usb
    -device usb-tablet
    -monitor stdio
    # below is a qemu api scriptable via json
    -chardev socket,id=qmp,path="/tmp/${NETNAME}/qmp.sock",server=on,wait=off
    -mon chardev=qmp,mode=control,pretty=on
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
)

# define a graphical backend, either x11 or wayland, defaults to x11
# does not depend on host choice, freely choosable
if [[ ${GFX_BACKEND} != @(x11|wayland) ]] ; then
    GFX_BACKEND=x11
fi

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

# for a gpu, we have two choices, either intel or nvidia, defaults to nvidia
if [[ ${GPU_MODE} == *"intel"* ]]; then
    # intel
    DRI_PRIME=pci-0000_00_02_0 VAAPI_MPEG4_ENABLED=true __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
else
    # nvidia, we dont use primus or bumblebee, but env vars (i tend to deinstall bumblebee and primus stuff...)
    __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"
fi

exit 0
