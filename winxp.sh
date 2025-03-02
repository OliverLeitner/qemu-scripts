#!/bin/bash
# start cmd: ./vm.sh <nvidia|intel> <x11|wayland> [1,2,3... cores you want to use] [recovery]

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
    # attention: windows might loose its activation
    # if you change the number of cores
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
# windows xp 32bit seems to run better with i386 than x86_64
BOOT_BIN=/usr/bin/qemu-system-i386
# windows xp 32bit can by default only address 3,something gigs of ram
MEM=4G
# monitor resolution in pixels
declare -A SCREENSIZE
SCREENSIZE[width]=1920
SCREENSIZE[height]=1080
# spice remove connection
SPICE_PORT=6000
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
#DP=sdl,gl=on,show-cursor=off
DP=egl-headless,rendernode=${RENDER}
MTYPE=pc,dump-guest-core=off,mem-merge=on,smm=on,vmport=auto,nvdimm=off,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kernel_irqchip=on
# get the number of cores based upon our selected cores
_num_selected=$(echo $CPU_SELECTED|awk -F',' '{print NF}')
CPU=$_num_selected,maxcpus=$_num_selected,cores=$_num_selected,sockets=1,threads=1,dies=1
# for most uefi systems, you want ovmf
BIOS=/usr/share/OVMF/OVMF_CODE.fd
# for older operating systems and efi, seabios is just fine
SEABIOS=/usr/share/seabios
# in case of uefi/ovmf, we store our vars user writeable
VARS=${VMDIR}/ovmf/OVMF_VARS-${NETNAME}.fd
UUID="$(uuidgen)"
# path to the operating system iso
ISODIR=/data/isos/os
# path to the vm image
VMDIR=/virtualisation
# path to our recovery iso
RECOVERYISO=/data/isos/HBCD_PE_x64.iso
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
    RECOVERYINFO="-boot order=d,menu=on,strict=on,splash-time=30 -drive id=drive1,file=${RECOVERYISO},index=1,media=cdrom -drive file=${ISODIR}/virtio-win-0.1.173.iso,media=cdrom,index=2,format=raw"
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
    -nodefaults
    -uuid ${UUID}
    -name ${NETNAME},process=${NETNAME},debug-threads=on
    -pidfile "/tmp/${NETNAME}/${NETNAME}.pid"
    #-parallel none
    #-serial none
    #-no-user-config
    #-no-acpi
    #-cpu core2duo
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,vmware-cpuid-freq=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    -smp ${CPU}
    -m ${MEM}
    #-bios ${SEABIOS}/bios.bin
    -L ${SEABIOS}/
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    #-global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    #-global kvm-pit.lost_tick_policy=delay
    -mem-prealloc
    -rtc base=localtime
    # the menu helps, when running winjumper
    #-boot order=c,menu=on,strict=on,splash-time=20000
    -object iothread,id=iothread0
    # recovery mode
    ${RECOVERYINFO}
    #-device virtio-scsi-pci,id=scsi,iothread=iothread0
    #-device scsi-hd,drive=drive1
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,index=0,media=disk,format=qcow2,index=0,if=none,cache=none,cache.direct=off,aio=io_uring
    # one needs to install winxp first onto standard virtio, the jumper helps with conversion to sd later on
    #-drive id=drive1,file=${VMDIR}/winxpjumper.qcow2,media=disk,format=qcow2,index=1,if=none,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,drive=drive0,num-queues=8,iothread=iothread0
    #-drive file=${ISODIR}/os/winxp/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso,media=cdrom,index=2,format=raw
    # 0.1.73 (archives) is the last virtio with xp install support of win-gt
    #-drive file=${ISODIR}/virtio-win-0.1.173.iso,media=cdrom,index=3,format=raw
    #-hdb fat:rw:${HOSTDIR}
    #-device usb-storage,drive=shared0
    #-drive file=fat:rw:/data/isos/shared,id=shared0,format=raw,if=none
    #-device usb-storage,drive=shared1
    #-drive file=fat:rw:/data/isos/shared-2,id=shared1,format=raw,if=none
    #-chardev socket,id=chrtpm,path=/tmp/${NETNAME}/swtpm-sock-${NETNAME}
    #-tpmdev emulator,id=tpm0,chardev=chrtpm
    #-device tpm-crb,tpmdev=tpm0
    #-device vmcoreinfo
    #-device vmgenid
    -enable-kvm
    -object memory-backend-memfd,id=mem1,share=on,merge=on,size=${MEM}
    -machine ${MTYPE},${ACCEL}
    #-object memory-backend-file,size=4G,share=on,mem-path=/dev/shm/ivshmem,id=hostmem
    -overcommit mem-lock=off
    #-overcommit cpu-pm=on
    #-device ${SHMEM}
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0,max-bytes=1024,period=1000
    #-device intel-iommu
    -device virtio-serial-pci
    #-device virtio-serial
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -chardev spicevmc,id=vdagent0,name=vdagent
    -device virtserialport,chardev=vdagent0,name=com.redhat.spice.0
    # usb redirect (from qemu documentation). this recognizes my external usb dvd drive just fine...
    #-readconfig /etc/qemu/ich9-ehci-uhci.cfg
    -chardev spicevmc,name=usbredir,id=usbredirchardev1
    -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev2
    -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2,debug=0
    -chardev spicevmc,name=usbredir,id=usbredirchardev3
    -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3,debug=0
    #-device virtio-vga-gl,edid=on,xres=${SCREENSIZE[width]},yres=${SCREENSIZE[height]}
    #-device virtio-gpu-gl-pci,edid=on
    #-device cirrus-vga
    #-device ati-vga,model=rage128p
    #-device VGA
    #-vga none
    -device qxl-vga,ram_size=524288,vram_size=524288,vgamem_mb=512
    #-device vmware-svga
    #-global vmware-svga.vgamem_mb=512
    #-spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -spice ${SPICE_MODE}
    -display ${DP}
    -device virtio-net-pci,netdev=net0,mac=${MAC},rombar=0,packed=on,rx_queue_size=256,tx_queue_size=256,disable-modern=off,page-per-vq=on
    #-device rtl8139,rombar=0,netdev=net0,mac=${MAC}
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    #-netdev user,id=net0,ipv6=off
    #-audiodev sdl,id=snd0
    -audiodev ${AUDIO_SERVER}
    #-device intel-hda
    #-device hda-duplex,audiodev=snd0
    #-audiodev sdl,id=sdl0
    -device ac97,audiodev=snd0
    #-device sb16 #,audiodev=snd0
    #-device gus
    #-device adlib
    -usb
    -device usb-ehci
    #-device piix3-usb-uhci
    -device usb-tablet
    #-device usb-kbd
    #-device usb-mouse
    #-device virtio-keyboard-pci
    #-device virtio-mouse-pci
    -monitor stdio
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
    DRI_PRIME=pci-0000_00_02_0 VIRGL_RENDERER_ASYNC_FENCE_CB=1 VAAPI_MPEG4_ENABLED=true VGL_READBACK=bpo __GLX_VENDOR_LIBRARY_NAME=mesa GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="i915" ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
else
    # nvidia
    _VIRGL_RENDERER_ASYNC_FENCE_CB=1 _NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true VGL_READBACK=pbo __GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 CLUTTER_BACKEND=${GFX_BACKEND} GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" ${cpu_affinity} ${BOOT_BIN} "${args[@]}"
fi

exit 0
