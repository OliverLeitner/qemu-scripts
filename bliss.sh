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
SPICE_PORT=5930
# RAM
MEM=8G
# monitor resolution in pixels
declare -A SCREENSIZE
SCREENSIZE[width]=1920
SCREENSIZE[height]=1080
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
#DP=sdl
MTYPE=q35,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=on,hmat=on,memory-backend=mem1
#MTYPE=q35
ACCEL=accel=kvm #,shadow-mem=256000000
UUID="$(uuidgen)"
# get the number of cores based upon our selected cores
_num_selected=$(echo $CPU_SELECTED|awk -F',' '{print NF}')
CPU=$_num_selected,maxcpus=$_num_selected,cores=$_num_selected,sockets=1,threads=1,dies=1
# path to the vm image
VMDIR=/virtualisation
# path to the operating system iso
ISODIR=/applications/OS/isos
# path to our recovery iso
RECOVERYISO=/path/to/recovery.iso
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
    -cpu host,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -mem-prealloc
    #-global kvm-pit.lost_tick_policy=delay
    #-rtc base=localtime
    -parallel none
    -serial none
    -drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd"
    -drive "if=pflash,format=raw,file=${HOME}/scripts/${NETNAME}/my_vars.fd"
    -object iothread,id=iothread0
    # recovery mode
    ${RECOVERYINFO}
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,if=none,format=qcow2,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,drive=drive0,num-queues=4,iothread=iothread0
    # installer image (bliss os update should be able to roll that way...)
    #-drive id=drive1,file="${ISODIR}/android/Bliss-v16.9.7-x86_64-OFFICIAL-gapps-20241011.iso",media=cdrom
    -chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    -tpmdev emulator,id=tpm0,chardev=chrtpm
    -device tpm-crb,tpmdev=tpm0
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    -overcommit mem-lock=off
    #-overcommit cpu-pm=on
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0
    -device virtio-serial-pci
    -device virtio-serial
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
    -device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    -audiodev ${AUDIO_SERVER}
    #-audiodev sdl,id=sdl0
    -device ich9-intel-hda
    -device hda-duplex,audiodev=snd0
    -device hda-micro,audiodev=snd0
    #-device ac97,audiodev=sdl0
    #-vga virtio
    #-vga none
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    -device virtio-vga-gl,edid=on,xres=${SCREENSIZE[width]},yres=${SCREENSIZE[height]}
    -spice ${SPICE_MODE}
    -display ${DP}
    # usb redirect
    #-readconfig /etc/qemu/ich9-ehci-uhci.cfg
    -chardev spicevmc,name=usbredir,id=usbredirchardev1
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev2
    -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev3
    -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3,debug=0
    -usb
    -device nec-usb-xhci
    -device usb-tablet
    -monitor stdio
    # you might want a serial port on android
    #-chardev tty,path=/dev/ttyUSB0,id=hostusbserial
    #-device pci-serial,chardev=hostusbserial
    # below is a qemu api scriptable via json
    -chardev socket,id=qmp,path="/tmp/${NETNAME}/qmp.sock",server=on,wait=off
    -mon chardev=qmp,mode=control,pretty=on
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
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

#create tmp dir if not exists
if [ ! -d "/tmp/${NETNAME}" ]; then
    mkdir /tmp/${NETNAME}
fi

#create myvars if not exists
if [ ! -f "${HOME}/scripts/${NETNAME}/my_vars.fd" ]; then
    mkdir -p ${HOME}/scripts/${NETNAME} >/dev/null
    cp /usr/share/OVMF/OVMF_VARS_4M.fd ${HOME}/scripts/${NETNAME}/my_vars.fd
fi

# check if the bridge is up, if not, dont let us pass here
if [[ $(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1 }') != *tap0-${NETNAME}* ]]; then
    echo "bridge is not running, please start bridge interface"
    exit 1
fi

# get tpm going
exec swtpm socket --tpm2 --tpmstate dir=/tmp/${NETNAME} --terminate --ctrl type=unixio,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME} --daemon &

if [[ ${GPU_MODE} == *"intel"* ]]; then
    # intel
    DRI_PRIME=pci-0000_00_02_0 VAAPI_MPEG4_ENABLED=true VDPAU_DRIVER="i915" GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
else
    # nvidia
    __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
fi

exit 0
