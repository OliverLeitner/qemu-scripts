#!/bin/bash
# intel
#DRI_PRIME=pci-0000_00_02_0 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="i915" /usr/bin/remote-viewer
# nvidia
DRI_PRIME=pci-0000_01_00_0 GTK_BACKEND=x11 GDK_BACKEND=x11 QT_BACKEND=x11 VDPAU_DRIVER="nvidia" /usr/bin/remote-viewer
exit 0
