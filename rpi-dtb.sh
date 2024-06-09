#!/bin/bash
BOOT_BIN=/usr/bin/qemu-system-aarch64
MEM=1G
NETNAME=$(basename $0 |cut -d"." -f 1)
#NETNAME=rpi
MAC=$(grep -e "${NETNAME}=" macs.txt |cut -d"=" -f 2)
rasp=/virtualisation/rpi
CPU=4,maxcpus=4,cores=4,sockets=1,threads=1
UUID="$(uuidgen)"

# from boot/cmdline.txt
#console=tty0 console=ttyS1,115200 root=LABEL=RASPIROOT rw fsck.repair=yes net.ifnames=0 cma=64M rootwait

args=(
    -nographic
    -uuid ${UUID}
    -machine raspi3b
    -cpu cortex-a72
    -smp ${CPU}
    -m ${MEM}
    -object memory-backend-memfd,id=mem1,share=on,size=${MEM}
    -mem-prealloc
    -overcommit mem-lock=off
    -object rng-random,id=objrng0,filename=/dev/urandom
    -chardev socket,id=agent0,path="/tmp/${NETNAME}/${NETNAME}-agent.sock",server=on,wait=off
    -dtb ${rasp}/bcm2837-rpi-3-b.dtb
    -kernel ${rasp}/vmlinuz-6.1.0-18-arm64
    -drive file=${rasp}/20231109_raspi_3_bookworm.img,index=0,media=disk,if=sd,cache=none,cache.direct=off,aio=io_uring,format=raw
    -append "root=LABEL=RASPIROOT rootfstype=ext4 rw fsck.repair=1 net.ifnames=0 cma=64M dwc_otg.lpm_enable=0 rootwait console=tty0 console=ttyS1,115200 console=ttyAMA0,115200 ipv6.disable=1"
    -initrd ${rasp}/initrd.img-6.1.0-18-arm64
    # network just doesnt work currently with dtb on
    -usb
    -device usb-net,netdev=net0
    #-netdev user,id=net-usb1,restrict=on
    #-device usb-net,netdev=net-usb1
    #-device ne2k_pci,netdev=net0
    #-netdev user,id=net0,hostfwd=tcp::5555-:22
    -netdev tap,ifname=tap0-${NETNAME},script=no,downscript=no,id=net0
    # below is a qemu api scriptable via json
    -chardev socket,id=qmp,path="/tmp/${NETNAME}/qmp.sock",server=on,wait=off
    -mon chardev=qmp,mode=control,pretty=on
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

${BOOT_BIN} "${args[@]}"

exit 0
