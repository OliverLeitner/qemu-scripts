#!/bin/bash
# simple tap creator script

# name of the master bridge device
BRIDGE_IF=br0
# directory, that contains the qemu startup scripts
STARTSCRIPT_DIR=$(dirname $0)

# including help function library
source ${STARTSCRIPT_DIR}"/help.sh"

NAME=$1
CMD=$2
# cuts the info out we need for a listing
MACHINELIST=$(grep NETNAME= ${STARTSCRIPT_DIR}/*.sh | cut -d'=' -f1 | gawk -F. '{ print $1 }' | sed -e 's/bridge//' | gawk -F/ '{ print $NF }')
# gets the mac of the machine for handling
MAC=$(grep -e "${NAME}=" ${STARTSCRIPT_DIR}/macs.txt |cut -d"=" -f 2)

# function that lists all available vms and shows if a TAP interface is active for it or not
function list_interfaces() {
    for _file in ${STARTSCRIPT_DIR}/*.sh; do
        _netname=$(basename $_file |cut -d"." -f 1)
        # output formatting
        _netname_padded=$(printf %-10s ${_netname})
        _bridgename=$(ip addr | grep ${_netname} | cut -d ':' -f 2 | cut -d '-' -f 2)
        if [[ $MACHINELIST == *${_netname}* ]]; then
            if [[ ${_bridgename} == "" ]]; then
                echo -e "${_netname_padded} \033[0m not active\033[0m"
            fi
            if [[ ${_bridgename} != "" ]]; then
                echo -e "${_netname_padded} \033[0;32m active\033[0m"
            fi
        fi
    done
}

function delete_interface() {
    sudo ip link delete tap0-${NAME}
}

function create_interface() {
    sudo ip tuntap add tap0-${NAME} mode tap user ${USER}
    sudo ip link set dev tap0-${NAME} up
    sudo ip link set tap0-${NAME} master ${BRIDGE_IF}
    #if [[ ${NAME} == haiku ]]; then
    #    sudo ip addr add 192.168.2.238/24 brd + dev tap0-${NAME}
    #fi
    # vdpa support
    #vdpa dev add name vdpa-${NAME} mgmtdev vdpasim_net ${MAC}
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

    case ${CMD} in
        start)
            create_interface
            echo "TAP interface for ${NAME} has been created."
        ;;
        stop)
            delete_interface
            echo "TAP interface for ${NAME} has been deleted."
        ;;
        *)
            help_interface
    esac

    exit 0
fi

# if name is not a machine, its probably something else
case ${NAME} in
    ls)
        echo -e "available machines:\n"
        list_interfaces
        echo -e "\n"
        exit 0
    ;;
    list)
        echo -e "available machines:\n"
        list_interfaces
        echo -e "\n"
        exit 0
    ;;
    help|-help|--help|-h|--h|?|-?|--?)
        help_interface
        exit 0
    ;;
    *)
        echo -e "\n"
        echo -e "virtual machine does not exist\n"
        help_interface
        exit 0
    ;;
esac

exit 0
