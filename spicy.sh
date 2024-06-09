#!/bin/bash
# ./command.sh <nvidia|intel> <x11|wayland>

# including help function library
source "./help.sh"

# lets have a choice upon gpu, intel or nvidia, defaults to nvidia
GPU_MODE=$1
# adding the GFX_BACKEND (x11, wayland), defaults to x11
GFX_MODE=$2
# sometimes we want to add an uri, i.e. if we are on a socket
URI=$3

# example run:
#
# with uri:
#   spicy intel x11 spice+unix:///tmp/windows10-spice.sock
#
# without uri:
#   spicy intel x11

# lets have some commandline help
case ${GPU_MODE} in
    help|--help|-h|"")
        help_remote
        exit 1
    ;;
esac

_uri=""

if [[ ${URI} != "" ]]; then
    _uri=--uri=${URI}
fi

# define a graphical backend, either x11 or wayland, defaults to x11
# does not depend on host choice, freely choosable
if [[ ${GFX_BACKEND} != @(x11|wayland) ]] ; then
    GFX_BACKEND=x11
fi

NV_CMD=__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=mesa DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" /usr/bin/spicy ${_uri}
GVT_CMD=DRI_PRIME=pci-0000_00_02_0 VAAPI_MPEG4_ENABLED=true GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="i915" /usr/bin/spicy ${_uri}

case $GPU_MODE in
    intel)
        # intel
        ${GVT_CMD}
        ;;
    nvidia)
        # nvidia
        ${NV_CMD}
        ;;
    *)
        # fallback to nvidia
        ${NV_CMD}
        ;;
esac

exit 0
