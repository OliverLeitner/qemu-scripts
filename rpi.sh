#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-aarch64
NETNAME=rpi
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
HOSTNAME=${NETNAME}
rasp=/virtualisation/rpi
CPU=2,maxcpus=2,cores=2,sockets=1,threads=1
UUID="$(uuidgen)"
MEM=1G

# from boot/cmdline.txt
#console=tty0 console=ttyS1,115200 root=LABEL=RASPIROOT rw fsck.repair=yes net.ifnames=0 cma=64M rootwait

args=(
    -nographic
    -uuid ${UUID}
    -machine virt
    -cpu cortex-a72
    -smp ${CPU}
    -m ${MEM}
    -kernel ${rasp}/vmlinuz-6.1.0-18-arm64
    -object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -mem-prealloc
    -overcommit mem-lock=off
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on
    -object rng-random,id=objrng0,filename=/dev/urandom
    -device virtio-rng-pci,rng=objrng0,id=rng0
    -device virtio-serial-pci
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -device virtserialport,chardev=agent0,name=org.qemu.guest_agent.0
    -object iothread,id=iothread0
    -drive id=drive0,file=${rasp}/20231109_raspi_3_bookworm.img,format=raw,media=disk,index=0,if=none,cache=none,cache.direct=off,aio=io_uring
    -device virtio-blk-pci,drive=drive0,iothread=iothread0
    -append "root=LABEL=RASPIROOT rootfstype=ext4 rw fsck.repair=1 net.ifnames=0 cma=64M rootwait console=tty0 console=ttyS1,115200 console=ttyAMA0,115200"
    -initrd ${rasp}/initrd.img-6.1.0-18-arm64
    -usb
    -device virtio-net-pci,netdev=net0
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
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

GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" ${BOOT_BIN} "${args[@]}"


exit 0
