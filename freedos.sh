#!/bin/bash
# start cmd: ./vm.sh <nvidia|intel> <x11|wayland> [recovery]

# including help function library
source $(dirname $0)"/help.sh"

# commandline parameters
GPU_MODE=$1
GFX_BACKEND=$2
RECOVERY_MODE=$3

# ---------------- settings start ------------------
BOOT_BIN=/usr/bin/qemu-system-i386
MEM=16M
SPICE_PORT=5950
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
DP=sdl,gl=on,show-cursor=off
#DP=egl-headless,rendernode=${RENDER}
MTYPE=pc,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=off,hpet=off,memory-backend=mem1
ACCEL=accel=kvm,kernel_irqchip=on
UUID="$(uuidgen)"
CPU=1,maxcpus=1,cores=1,sockets=1,threads=1
BIOS=/usr/share/OVMF/OVMF_CODE.fd
SEABIOS=/usr/share/seabios
HOSTDIR=/applications/incoming/dos/shared
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

# preparing recovery mode
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
    #-nodefaults
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME}
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    #-parallel none
    #-serial none
    #-no-user-config
    #-cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,vmware-cpuid-freq=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    -cpu pentium,sse2=off,vmx=off,hypervisor=off,kvm=off,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    #-bios ${SEABIOS}/bios.bin
    -L ${SEABIOS}/
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    #-global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    #-global kvm-pit.lost_tick_policy=delay
    #-mem-prealloc
    -rtc base=localtime
    #-boot order=c,menu=on,strict=on,splash-time=20000
    -object iothread,id=iothread0
    # recovery mode
    ${RECOVERYINFO}
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,media=disk,format=qcow2,index=0,if=none,cache=none,cache.direct=off,aio=io_uring
    #-drive file=/dev/cdrom,media=cdrom,index=2
    -device virtio-blk-pci,drive=drive0,num-queues=4,iothread=iothread0
    #-hdb fat:rw:${HOSTDIR}
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -device floppy
    #-device vmcoreinfo
    #-device vmgenid
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    #-overcommit mem-lock=off
    #-overcommit cpu-pm=on
    #-device ${SHMEM}
    #-device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    #-object rng-random,id=objrng0,filename=/dev/urandom
    #-device virtio-rng-pci,rng=objrng0,id=rng0,max-bytes=1024,period=1000
    #-device intel-iommu
    #-device virtio-serial-pci
    #-device virtio-serial
    #-chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    #-device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    #-chardev spicevmc,id=vdagent0,name=vdagent
    #-device virtserialport,chardev=vdagent0,name=com.redhat.spice.0
    #-device virtio-vga-gl,edid=on
    #-device virtio-gpu-gl-pci,edid=on
    -device cirrus-vga
    #-device ati-vga,model=rage128p
    #-device VGA
    #-vga none
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    #-device vmware-svga
    #-global vmware-svga.vgamem_mb=2
    #-spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    #-spice ${SPICE_MODE}
    -display ${DP}
    #-device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    -device pcnet,netdev=net0,mac=${MAC}
    # working nics: e1000 (instable), usb-net (super slow), pcnet (even slower), rtl8139, virtio-net-pci (instable)
    #-device rtl8139,netdev=net0,mac=${MAC} #,mq=on,packed=on
    #-netdev user,id=net0,ipv6=off
    #-audiodev sdl,id=snd0
    -audiodev ${AUDIO_SERVER}
    #-device ich9-intel-hda
    #-device hda-duplex,audiodev=snd0
    #-audiodev sdl,id=sdl0
    #-device ac97,audiodev=sdl0
    -device sb16,audiodev=snd0
    -device gus,audiodev=snd0
    -device adlib,audiodev=snd0
    -usb
    -device nec-usb-xhci
    #-device usb-tablet
    #-device usb-kbd
    #-device usb-mouse
    #-device virtio-keyboard-pci
    -device virtio-mouse-pci
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
#exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

# for a gpu, we have two choices, either intel or nvidia, defaults to nvidia
if [[ ${GPU_MODE} == *"intel"* ]]; then
    # intel
    DRI_PRIME=pci-0000_00_02_0 VIRGL_RENDERER_ASYNC_FENCE_CB=1 VAAPI_MPEG4_ENABLED=true VGL_READBACK=bpo GDK_SCALE=1 GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
else
    # nvidia
    VIRGL_RENDERER_ASYNC_FENCE_CB=1 __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true VGL_READBACK=pbo GDK_SCALE=1 GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"
fi

exit 0
