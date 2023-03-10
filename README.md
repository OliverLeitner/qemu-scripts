# QEMU Virtual Machine startup scripts

these are some common startup scripts for my set of vms

## howto use (granted you have a qcow2 file ready and adopted the scripts to your files and dirs and network IF):
- to start a vm:
    - ./bridge.sh netname start
    - ./netname.sh start
- to stop a vm:
    - power down the vm
    - ./bridge.sh netname stop

vm guest run as your user, dont need to be superuser, however, the net bridge and tap setup needs superuser by default, bridge.sh will ask you for your sudo password.

## included:

- arch.sh: arch gnu/linux startup script
- bliss.sh: bliss os (android) startup script
- debian.sh: debian gnu/linux startup script
- fedora.sh: fedora gnu/linux startup script
- haiku.sh: haiku os (BeOS clone) startup script
- lmde.sh: linux mint debian edition startup script (gnu/linux)
- osx.sh: MacOSX startup script
- ubuntu.sh: Ubuntu gnu/linux startup script
- void.sh: void gnu/linux startup script
- winplay10.sh: Windows 10 startup script
- winplay.sh: Windows 11 startup script
- freebsd.sh: FreeBSD 13.1 startup script
- bridge.sh: tap network starter script

## requirements:

- Linux host operating system (in my case: Ubuntu 22.04.2 LTS) with enabled KVM support
- Qemu 6.2.0 (qemu-system-x86_64)
- software emulated tpm (swtpm)
- OVMF uefi firmware binaries
- libvirglrenderer1
- qemu-guest-agent
- spice-vdagent
- libsdl-*
- X Windows System (xorg)
- uuid-runtime (uuidgen tool for generating unique process ids)
- a bridged network (br0) and a dhcp server, the scripts generate tap interfaces based upon it
- tested with an NVIDIA Card (GTX 750, RTX 3050 is what ive been using)
- Intel Core I3 8th gen (others are possible, this is just what i have been running em on...)
- base gnu tools in reasonably current versions: "bash", "cat", "grep", "ip", "cut", "brctl", "nmcli", "sudo"
- enough RAM and disk space to handle the machine(s)
- a file called "macs.txt" containing names and mac addresses of guests in the form of one "netname=mac" per line
- for MacOSX: a file called osxkey.txt containing the OSX key (one line, just the key)

## features:

- no host-blocking gpu/hardware sharing needed
- console access for restarting and handling the vm guests
- possibility for advanced sandboxing
- low latency desktop performance due to using sdl/virgl
- vulkan support
- opengl rendering through virgl
- full network access due to non-userspace networking
- tpm support / uefi support
- alot of configurable settings that are not accessible through tools like virt-manager or gnome-boxes
- video, audio, gaming, enjoy!

## limitations:

- no remote desktop (workaround possible through vnc, nx, xdmcp, rdp...)
- no headless mode
- no access to the hosts clipboard (some might call this a feature...) since i am not using spice as ui wrapper

## OS specific limitations:

- haiku.sh:
    - no support for gallium/virgl rendering, might be a bit sluggish
    - for some reason smb shares wont show up:
        workaround: using nfs to mount shares from within haiku

- osx.sh:
    - since it is running opencore, theres a bit of latency

- fedora.sh:
    - if you are using fedora with its default btrfs filesystem, this might cause a bit of latency

- bliss.os:
    - i have had problems getting other android distributions than bliss os running stable or at all

- winplay.sh, winplay10.sh:
    - windows virgl/vulkan support is still limited

- freebsd.sh:
    - freebsd currently neither supports qxl nor virtio gpu's, using vmware gfx meanwhile.
      as a result the experience is slightly sluggish, to get your mouse back from being captured
      use ctrl+alt+g to escape the capturing.

## why?

ive been using virt-manager / libvirtd for years now, they have their place in running stable vm guests,
however, virt-manager has its limitations. if you really want to go the virsh way, youll have to
add some qemu start parameters anyways to get non-virt-manager qemu parameters in plus youve always
got the overhead of wrapping libvirtd around your qemu, thus the latency will be higher...

## a few facts:

i have been running these vm guests with the scripts over the last 3 years, things are now in a fully
proven stable state, so i am sharing these with the world.

## enjoy!

if you have any further questions or ideas, please let me know, i do love feedback, hope youll find
these scripts useful.
