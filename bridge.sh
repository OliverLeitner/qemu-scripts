#!/bin/bash
# simple tap creator script
NAME=$1
CMD=$2
# name of the master bridge device
BRIDGE_IF=br0
# directory, that contains the qemu startup scripts
STARTSCRIPT_DIR=~/scripts
# cuts the info out we need for a listing
MACHINELIST=`grep NETNAME= ${STARTSCRIPT_DIR}/*.sh | cut -d'=' -f1 | gawk -F. '{ print $1 }' | sed -e 's/bridge//' | gawk -F/ '{ print $NF }'`

function delete_bridge() {
    sudo ip link delete tap0-${NAME}
}

function create_bridge() {
    sudo ip tuntap add tap0-${NAME} mode tap user ${USER}
    sudo ip link set dev tap0-${NAME} up
    sudo ip link set tap0-${NAME} master ${BRIDGE_IF}
    #if [[ ${NAME} == haiku ]]; then
    #    sudo ip addr add 192.168.2.238/24 brd + dev tap0-${NAME}
    #fi
}

# if machinename was found, we do machine stuff
if [[ $MACHINELIST == *$NAME* ]]; then

    if [[ `nmcli device status |grep tap0-${NAME}` == *"tap0-${NAME}"* ]] && [[ $CMD == "start" ]]; then
        echo "TAP for ${NAME} is already running."
        exit 1
    fi

    if [[ `nmcli device status |grep tap0-${NAME}` != *"tap0-${NAME}"* ]] && [[ $CMD == "stop" ]]; then
        echo "TAP for ${NAME} does not exist."
        exit 1
    fi

    case $CMD in
        start)
            create_bridge
            echo "bridge if created"
        ;;
        stop)
            delete_bridge
            echo "stopped the tap if"
        ;;
        *)
            echo "parameter missing"
    esac

    exit 0
fi


# if name is not a machine, its probably something else
case $NAME in
    list)
        echo available machines:
        echo $MACHINELIST
        exit 0
    ;;
    *)
        echo "machine does not exist"
        exit 0
esac

exit 0
