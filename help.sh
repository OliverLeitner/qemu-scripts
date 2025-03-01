#!/bin/bash
# this file holds the functions for help output

# help information for the virtual machine scripts
function help_vm() {
    help=("\n"
        " this script starts up a virtual machine           \n"
        " make sure that you have run the bridge.sh         \n"
        " script first.                                     \n"
        "                                                   \n"
        " the following options are available to you:       \n"
        "                                                   \n"
        " ${0} <gpu> <graphics server> [recovery]           \n"
        "                                                   \n"
        "   available gpu options:                          \n"
        "                                                   \n"
        "   intel (iGPU)                                    \n"
        "   nvidia (external)                               \n"
        "                                                   \n"
        "   available graphics server options:              \n"
        "                                                   \n"
        "   x11     (legacy graphics server)                \n"
        "   wayland (modern graphics server)                \n"
        "                                                   \n"
        "                                                   \n"
        "   the next thing you can provide                  \n"
        "   is the list of comma separated                  \n"
        "   cpu cores you want to run on                    \n"
        "                                                   \n"
        "   1,2 will have your vm run on                    \n"
        "   core 1 and core 2 of your cpu                   \n"
        "                                                   \n"
        "                                                   \n"
        "   the option recovery will start an               \n"
        "   live recovery iso instead of the                \n"
        "   vm, see the script for the line                 \n"
        "   RECOVERYISO= and change it to your              \n"
        "   needs.                                          \n"
        "                                                   \n"
        " as soon as the vm is running, you will be         \n"
        " provided with the information needed              \n"
        " to access the vm and a qemu shell that            \n"
        " lets you shutdown or restart the vm as needed.    \n"
    )

    echo -e "${help[@]}"
}

# spicy and remote-viewer help
function help_remote() {
    help=("\n"
        " this script will start a remote connection tool   \n"
        "                                                   \n"
        " the following options are available to you:       \n"
        "                                                   \n"
        " ${0} <gpu> <graphics server> [uri]                \n"
        "                                                   \n"
        "   available gpu options:                          \n"
        "                                                   \n"
        "   intel (iGPU)                                    \n"
        "   nvidia (external)                               \n"
        "                                                   \n"
        "   available graphics server options:              \n"
        "                                                   \n"
        "   x11     (legacy graphics server)                \n"
        "   wayland (modern graphics server)                \n"
        "                                                   \n"
        "   optional connection URI:                        \n"
        "                                                   \n"
        "   sample: spice+unix:///tmp/vmname/spice.sock     \n"
    )

    echo -e "${help[@]}"
}


# network setup command help
function help_interface() {
    help=("\n"
        " to get a list of available virtual machines:      \n"
        "                                                   \n"
        "   ${0} ls                                         \n"
        "   ${0} list                                       \n"
        "                                                   \n"
        " to start a TAP interface for a virtual machine:   \n"
        "                                                   \n"
        "   ${0} [virtual machine name] start               \n"
        "                                                   \n"
        " to stop a TAP interface for a virtual machine:    \n"
        "                                                   \n"
        "   ${0} [virtual machine name] stop                \n"
    )

    echo -e "${help[@]}"
}
