#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-x86_64
SPICE_PORT=5970
MEM=4G
# intel render node
GVT_RENDER=/dev/dri/by-path/pci-0000:00:02.0-render
# nvidia render node
NV_RENDER=/dev/dri/by-path/pci-0000:01:00.0-render
NETNAME=$(basename $0 |cut -d"." -f 1)
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
#DP=gtk
#DP=sdl,show-cursor=off
#DP=sdl,gl=on,show-cursor=off
DP=egl-headless,rendernode=${NV_RENDER} #rendernode=/dev/dri/by-path/pci-0000:00:02.0-render
#DP=sdl,gl=on
#SHMEM=ivshmem-plain,memdev=hostmem
#MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=on,nvdimm=off,hmat=on
MTYPE=pc-q35-6.2,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=on,nvdimm=off,hmat=on,memory-backend=mem1
#MTYPE=pc-q35-6.2,vmport=off,mem-merge=on,smm=on,nvdimm=off,hmat=on,memory-backend=mem1
#MTYPE=pc,accel=kvm,dump-guest-core=off,mem-merge=on,smm=on,vmport=on,nvdimm=off,hmat=on,memory-backend=mem1
ACCEL=accel=kvm #,kernel_irqchip=on #,kvm-shadow-mem=256000000
UUID="$(uuidgen)"
CPU=2,maxcpus=2,dies=1,cores=2,sockets=1,threads=1
ISODIR=/applications/OS/isos
VMDIR=/virtualisation

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
    #-parallel none
    #-serial none
    #-nodefaults
    #-no-user-config
    #-cpu Penryn,vmx=off,hypervisor=off,kvm=on,vendor=GenuineIntel,vmware-cpuid-freq=on,+invtsc,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check
    -cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,vmware-cpuid-freq=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on,pcid=off,spec-ctrl=off
    #-cpu host,vmx=on,hypervisor=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vendor-id=1234567890,kvm=on
    #-cpu kvm64
    #-cpu host,kvm=on,vmx=on,hypervisor=on,vendor=GenuineIntel #,vmware-cpuid-freq=on
    #-cpu host
    -smp ${CPU}
    -m ${MEM}
    -smbios type=2,manufacturer="oliver",product="${NETNAME}starter",version="0.1",serial="0xDEADBEEF",location="github.com",asset="${NETNAME}"
    -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
    -mem-prealloc
    #-global kvm-pit.lost_tick_policy=delay
    #-rtc base=localtime
    -object iothread,id=iothread0
    #-drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd"
    #-drive "if=pflash,format=raw,file=/tmp/${NETNAME}/my_vars.fd"
    #-drive file=${ISODIR}/bsd/install74.iso,media=cdrom
    -drive id=drive0,file=${VMDIR}/${NETNAME}.qcow2,media=disk,if=none,format=qcow2,cache=none,aio=io_uring,cache.direct=off
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
    # freebsd cannot handle virtio devices, theres no virtio gpu support built in
    #-device virtio-vga-gl,xres=1920,yres=1080
    #-vga none
    #-vga virtio
    # bsd qxl is party broken, cant handle modern compositors, sluggish at best...
    #-device qxl-vga
    #-global qxl-vga.ram_size=524288 -global qxl-vga.vram_size=524288 -global qxl-vga.vgamem_mb=512
    # vmware-svga is the current stable thing to do on freebsd, it aint perfect (system load) but its the most stable
    -device vmware-svga
    -global vmware-svga.vgamem_mb=512
    #-spice agent-mouse=off,addr=/tmp/${NETNAME}/spice.sock,unix=on,disable-ticketing=on,rendernode=${NV_RENDER}
    -spice agent-mouse=off,addr=127.0.0.1,port=${SPICE_PORT},disable-ticketing=on,image-compression=off,jpeg-wan-compression=never,zlib-glz-wan-compression=never,streaming-video=off,playback-compression=off,rendernode=${NV_RENDER}
    -display ${DP}
    -device virtio-net-pci,rx_queue_size=256,tx_queue_size=256,mq=on,packed=on,netdev=net0,mac=${MAC},indirect_desc=off #,disable-modern=off,page-per-vq=on
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,vhost=off,poll-us=50000,id=net0
    #-audiodev pa,id=snd0,server=unix:/run/user/1000/pulse/native,out.mixing-engine=off
    -audiodev sdl,id=snd0
    #-device intel-hda
    #-device ich9-intel-hda
    #-device intel-hda
    #-device hda-micro,audiodev=pa
    #-device ac97,audiodev=snd0
    #-chardev pty,id=charserial0
    #-device isa-serial,chardev=charserial0,id=serial0
    #-chardev spicevmc,id=charchannel0,name=vdagent
    #-device virtio-keyboard
    #-device virtio-tablet-pci
    #-device virtio-mouse-pci
    -usb
    #-device usb-ehci,id=ehci
    #-device nec-usb-xhci,id=xhci
    -device qemu-xhci
    -device usb-audio,multi=on,audiodev=snd0
    -device usb-tablet #,bus=usb-bus.0
    #-device usb-kbd
    #-device usb-mouse
    #-device virtio-tablet-pci
    -monitor stdio
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny
    -k de
    #-full-screen
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
#QEMU_AUDI_DRV="sdl" DRI_PRIME=pci-0000_00_02_0 GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="i915" ${BOOT_BIN} "${args[@]}"
# nvidia
QEMU_AUDIO_DRV="sdl" DRI_PRIME=pci-0000_01_00_0 GALLIUM_DRIVER=zink GDK_SCALE=1 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"

#close up script
exit 0
