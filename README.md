# QEMU Virtual Machine startup scripts

Readme last updated: 24.02.2024

these are some common startup scripts for my set of vms

## howto use (granted you have a qcow2 file ready and adopted the scripts to your files and dirs and network IF):
- to start a vm:
    - ./bridge.sh netname start
    - ./netname.sh start
- to stop a vm:
    - power down the vm
    - ./bridge.sh netname stop
- to list available vms:
    - ./bridge.sh list

vm guest run as your user, dont need to be superuser, however, the net bridge and tap setup needs superuser by default, bridge.sh will ask you for your sudo password.

## included:

### machines

- arch.sh:                      arch gnu/linux startup script
- bliss.sh:                     bliss os (android) startup script
- debian.sh:                    debian gnu/linux startup script
- fedora.sh (not in use):       fedora gnu/linux startup script
- haiku.sh:                     haiku os (BeOS clone) startup script
- lmde.sh (not in use):         linux mint debian edition startup script (gnu/linux)
- osx.sh (not in use):          MacOSX startup script
- ubuntu.sh (not in use):       Ubuntu gnu/linux startup script
- void.sh:                      void gnu/linux startup script
- winplay10.sh (not in use):    Windows 10 startup script
- winplay.sh:                   Windows 11 startup script
- freebsd.sh (not in use):      FreeBSD current startup script
- netbsd.sh (not in use):       NetBSD current EFI startup script
- netbsd-uefi.sh (not in use):  NetBSD current UEFI startup script
- openbsd.sh:                   OpenBSD current startup script
- rpi.sh:                       Starting a Raspberry PI image generic version
- rpi-dtb.sh:                   Starting a Raspberry PI 3B image with dtb loaded
- chromeos.sh (not in use):     ChromeOS Flex current startup script.
- freedos.sh                    FreeDOS current startup script.

----------------------------------------------------------------------------

### tools

- bridge.sh:                    tap network starter script

----------------------------------------------------------------------------

### viewer enhancements

- remove-viewer.sh:             remote viewer wrapper with switch to specific GPU
- spicy.sh:                     spicy viewer wrapper with switch to specific GPU

## requirements:

- HOST: Linux host operating system (in my case: Ubuntu 22.04.2 LTS) with enabled KVM support
- HOST: Qemu 6.2.0 or newer (qemu-system-x86_64), newer versions might need to switch some device names...
- HOST: uuid-runtime (uuidgen tool for generating unique process ids)
- HOST: a bridged network (br0) and a dhcp server, the scripts generate tap interfaces based upon it
- HOST: tested with an NVIDIA Card (GTX 750, RTX 3050 is what ive been using), INTEL integrated gfx (my cpu has an i915 compatible one...)
- HOSt: Intel Core I3 8th gen (others are possible, this is just what i have been running em on...)
- HOST: base gnu tools in reasonably current versions: "bash", "cat", "grep", "ip", "cut", "brctl", "nmcli", "sudo", "awk", "tr"
- HOST: enough RAM and disk space to handle the machine(s)
- HOST: a file called "macs.txt" containing names and mac addresses of guests in the form of one "netname=mac" per line

## optional:

- HOST: software emulated tpm (swtpm) (windows wants this now...)
- HOST: OVMF uefi firmware binaries (only needed for uefi hosts...)
- GUEST: libvirglrenderer1 (for gui vms, not rpi, not rpi-dtb)
- GUEST: qemu-guest-agent (not a requirement, but it makes sense...)
- GUEST: spice-vdagent (helps with all except netbsd (spice vdagent not avail.), openbsd (spice-vdagent not avail.), rpi (not needed, serial), rpi-dtb (not needed, serial))
- HOST: libsdl-* (if you are using DP=sdl or sdl as an audio server, no need for rpi, rpi-dtb)
- HOST/GUEST X Windows System (xorg) (no need on rpi, rpi-dtb, probably no need at all at host level... further tests required here... especially EGL through spice over it will be interesting)
- HOST: for MacOSX: a file called osxkey.txt containing the OSX key (one line, just the key)

## features:

- no host-blocking gpu/hardware sharing needed
- console access for restarting and handling the vm guests
- possibility for advanced sandboxing
- low latency desktop performance due to using egl/virgl
- vulkan support (utilizing MESA zink)
- opengl rendering through virgl
- option for EGL and virgl/opengl through spice
- full network access due to non-userspace networking
- tpm support / uefi support
- alot of configurable settings that are not accessible through tools like virt-manager or gnome-boxes
- video, audio, gaming, enjoy!
- advanced disk handling via iothread and block device (where possible)
- dynamic screen resolution in spice viewers (on machines where that is possible, not supported on bliss os)

## limitations:

currently none

## OS specific limitations:

- haiku.sh:
    - no support for gallium/virgl rendering, no real support for qxl or virtio-vga-gl.
      vmware-svga also seems to be broken (reports as vmware, but still vesa performance), everything reports as vesa.
    - for some reason smb shares wont show up in "SMB shares", manual mounting being the only option that works.
    - nfs mounts will crash your haiku system after a few minutes: haikus bad network stack combined with the vesa gfx.
    - smb mounts will crash your haiku system after a few minutes: haikus bad network stack combined with the vesa gfx.
    - one might take the beta status of haiku serious...

- osx.sh:
    - since it is running opencore, theres a bit of latency
    - system updates and version switching will break the guest, even if OSX-KVM says they are safe.

- fedora.sh:
    - if you are using fedora with its default btrfs filesystem, this might cause a bit of latency.

- bliss.os:
    - i have had problems getting other android distributions than bliss os running stable or at all.
    - does not support dynamic screen resolution based on host screen size.
    - screen artifacts in the vm if running non-spice.

- winplay.sh, winplay10.sh:
    - speed is a bit sluggish, even if you tweak windows to its full potential.

- freebsd.sh:
    - freebsd currently neither supports qxl nor virtio gpu's, using vmware-svga meanwhile.
      as a result the experience is slightly sluggish, to get your mouse back from being captured
      use ctrl+alt+g to escape the capturing.
      workaround: switch to current (qxl in current pkg repo "working"),
      however, still not perfect, does not work in sdl (spice only), also basically every desktop
      environment with settings and session management hardcrashes back to login manager...)
      known working window managers: i3, dwm, xmonad
    - freebsd zfs default is sluggish and causes high cpu load, stick to ufs.

- netbsd.sh / netbsd-uefi.sh:
    - netbsd does not support qxl, virtio. the best option here is the vmware-svga.
    - vlc is broken and has been broken (core dumping...) for quite a while now.

- openbsd.sh:
    - openbsd does have problems with all sound cards except the usb option.
      also, like with all other bsd's xorg video accel only works with vmware-svga.
    - the default FFS filesystem is performing rather poorly, use ufs if possible.

- rpi.sh/rpi-dtb.sh:
    - you are obviously limited by the architecture, no kvm accel, not more than 1 Gigabyte of RAM.
    - GUI should be possible, but for the level i am using PI's i dont need GUI.
    - no virtio things are available if the dtb is loaded and we are in full raspi3b emulation mode.

- chromeos.sh:
    - graphics are seriously broken, best bet would be taking the bliss os grub parameters, and try them here.
    - performance is sub par, alot of stuff is just crashing or hanging.
    - no block device supports, its an hda, and thats what it always will be.

## read more

- https://docs.blissos.org/configuration/configuration-through-command-line-parameters/
- https://docs.blissos.org/installation/install-in-a-virtual-machine/advanced-qemu-config/
- https://www.intel.com/content/www/us/en/developer/articles/guide/kvm-tuning-guide-on-xeon-based-systems.html
- https://developers.redhat.com/articles/2024/02/21/virtio-live-migration-technical-deep-dive#migration_of_the_guest_memory
- https://www.redhat.com/en/blog/hands-vdpa-what-do-you-do-when-you-aint-got-hardware

## why?

ive been using virt-manager / libvirtd for years now, they have their place in running stable vm guests,
however, virt-manager has its limitations. if you really want to go the virsh way, youll have to
add some qemu start parameters anyways to get non-virt-manager qemu parameters in plus youve always
got the overhead of wrapping libvirtd around your qemu, thus the latency will be higher...

## a few facts:

i have been running these vm guests with the scripts over the last 3 years, some of them 6 and longer, things are now in a fully
proven stable state, so i am sharing these with the world.

## enjoy!

if you have any further questions or ideas, please let me know, i do love feedback, hope youll find
these scripts useful.
