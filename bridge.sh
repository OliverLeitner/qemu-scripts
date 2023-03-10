#!/bin/bash
# simple tap creator script
NAME=$1
CMD=$2
BRIDGE_IF=br0

function delete_bridge() {
    sudo ip link delete tap0-${NAME}
}

function create_bridge() {
    sudo ip tuntap add tap0-${NAME} mode tap user ${USER}
    sudo ip link set dev tap0-${NAME} up
    sudo ip link set tap0-${NAME} master ${BRIDGE_IF}
}

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
