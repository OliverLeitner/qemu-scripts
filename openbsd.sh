#!/bin/bash
# start cmd: ./vm.sh <nvidia|intel> <x11|wayland> [1,2,3... cores you want to run on] [recovery]

# including help function library
source $(dirname $0)"/help.sh"

# commandline parameters
GPU_MODE=$1
GFX_BACKEND=$2
CPU_SELECTED=$3
RECOVERY_MODE=$3

# if we fill in the cpu affinity, then recovery mode gets
# corrected to flag number 4
_first_core=$(echo $CPU_SELECTED |cut -d "," -f 1)
_num_cpus=$(cat /proc/cpuinfo |grep processor |tail -n1 |cut -d " " -f 2)
if [ -n "$_first_core" ] && [ "$_first_core" -eq "$_first_core" ] 2>/dev/null; then
    RECOVERY_MODE=$4
else
    # if we dont have user input for the selected cores
    # we go with the last 4 cores of the cpu as default
    _num_total=4
    _num_cpus=$(cat /proc/cpuinfo |grep processor |tail -n1 |cut -d " " -f 2)
    _out_cpus=""

    while [ $_num_total -gt 0 ]; do
        _out_cpus+="${_num_cpus},"
        let _num_cpus=_num_cpus-1
        let _num_total=_num_total-1
    done

    CPU_SELECTED=${_out_cpus::-1}
fi

# ---------------- settings start ------------------
# which qemu binary to run through
BOOT_BIN=/usr/bin/qemu-system-x86_64
# spice remove connection
MEM=8G
# monitor resolution in pixels
declare -A SCREENSIZE
SCREENSIZE[width]=1920
SCREENSIZE[height]=1080
# spice remove connection
SPICE_PORT=5970
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
DP=egl-headless,rendernode=${RENDER}
#DP=sdl,gl=on
MTYPE=q35,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=on,nvdimm=on,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kernel_irqchip=on #,kvm-shadow-mem=256000000
UUID="$(uuidgen)"
# get the number of cores based upon our selected cores
_num_selected=$(echo $CPU_SELECTED|awk -F',' '{print NF}')
CPU=$_num_selected,maxcpus=$_num_selected,cores=$_num_selected,sockets=1,threads=1,dies=1
# path to the operating system iso
ISODIR=/applications/OS/isos
# path to the vm image
VMDIR=/virtualisation
# path to our recovery iso
RECOVERYISO=/data/isos/recovery.iso
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
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME},debug-threads=on
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    #-parallel none
    #-serial none
    #-nodefaults
    #-no-user-config
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,vmware-cpuid-freq=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    -mem-prealloc
    #-global kvm-pit.lost_tick_policy=delay
    #-rtc base=localtime
    #-boot order=c,menu=on,strict=on,splash-time=20000
    -object iothread,id=iothread0
    #-drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
    #-drive "if=pflash,format=raw,file=/tmp/${NETNAME}/my_vars.fd"
    #-drive file=${ISODIR}/install76.iso,media=cdrom
    ${RECOVERYINFO}
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,index=0,media=disk,if=none,format=qcow2,cache=none,aio=io_uring,cache.direct=off
    -device virtio-blk-pci,drive=drive0,num-queues=4,iothread=iothread0
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    #-object memory-backend-file,size=${MEM},share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    -overcommit mem-lock=off
    #-overcommit cpu-pm=on
    #-device ${SHMEM}
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0,max-bytes=1024,period=1000
    -device intel-iommu
    -device virtio-serial-pci
    -device virtio-serial
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -chardev spicevmc,id=vdagent0,name=vdagent
    -device virtserialport,chardev=vdagent0,name=com.redhat.spice.0
    #-device virtio-vga-gl,edid=on,xres=${SCREENSIZE[width]},yres=${SCREENSIZE[height]}
    #-device virtio-vga
    #-vga std
    #-vga virtio
    # bsd qxl is party broken, cant handle modern compositors, sluggish at best...
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    -device vmware-svga
    -global vmware-svga.vgamem_mb=1024
    -spice ${SPICE_MODE}
    -display ${DP}
    -device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    #-audiodev sdl,id=snd0
    -audiodev ${AUDIO_SERVER}
    -device intel-hda
    #-device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    -device hda-micro,audiodev=snd0
    -device ac97,audiodev=snd0
    #-chardev pty,id=charserial0
    #-device isa-serial,chardev=charserial0,id=serial0
    #-chardev spicevmc,id=charchannel0,name=vdagent
    #-device virtio-keyboard
    #-device virtio-tablet-pci
    #-device virtio-mouse-pci
    -usb
    #-device usb-ehci,id=ehci
    #-device nec-usb-xhci,id=xhci
    -device qemu-xhci,id=xhci
    -device usb-audio,multi=on,bus=xhci.0,audiodev=snd0
    -device usb-tablet,bus=xhci.0
    #-device usb-kbd
    #-device usb-mouse
    #-device virtio-tablet-pci
    -monitor stdio
    # below is a qemu api scriptable via json
    -chardev socket,id=qmp,path="/tmp/${NETNAME}/qmp.sock",server=on,wait=off
    -mon chardev=qmp,mode=control,pretty=on
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
    #-full-screen
)

# switch cpu affinity on, if the config is set
cpu_affinity=
if [[ ${CPU_SELECTED} != "" ]] && [[ ${CPU_SELECTED} != "0" ]] ; then
    cpu_affinity="taskset -c ${CPU_SELECTED}"
fi

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

#create myvars if not exists
#if [ ! -f "/tmp/${NETNAME}/my_vars.fd" ]; then
#    cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/${NETNAME}/my_vars.fd
#fi

# get tpm going
#exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

# for a gpu, we have two choices, either intel or nvidia, defaults to nvidia
if [[ ${GPU_MODE} == *"intel"* ]]; then
    # intel
    DRI_PRIME=pci-0000_00_02_0 VAAPI_MPEG4_ENABLED=true VDPAU_DRIVER="i915" GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
else
    # nvidia
    _NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
fi

#close up script
exit 0
