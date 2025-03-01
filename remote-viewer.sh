#!/bin/bash
# ./command.sh <nvidia|intel> <x11|wayland>

# including help function library
source $(dirname $0)"/help.sh"

# lets have a choice upon gpu, intel or nvidia, defaults to nvidia
GPU_MODE=$1
# choose our graphics backend, either x11 or wayland, defaults to x11
GFX_BACKEND=$2
# sometimes we want to add an uri, i.e. if we are on a socket
URI=$3

# example run:
#
# with uri:
#   remote-viewer intel spice+unix:///tmp/windows10-spice.sock
#
# without uri:
#   remote-viewer intel

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

NV_CMD=__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=mesa __GLX_VENDOR_LIBRARY_NAME=nvidia DRI_PRIME=pci-0000_01_00_0 VAAPI_MPEG4_ENABLED=true MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink GDK_SCALE=1 GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="nvidia" /usr/bin/remote-viewer ${_uri}
GVT_CMD=DRI_PRIME=pci-0000_00_02_0 VAAPI_MPEG4_ENABLED=true GTK_BACKEND=${GFX_BACKEND} GDK_BACKEND=${GFX_BACKEND} QT_BACKEND=${GFX_BACKEND} VDPAU_DRIVER="i915" /usr/bin/remote-viewer ${_uri}

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
