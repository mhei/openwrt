#!/bin/sh

# Assumptions:
# The image of the new target rootfs is gz compressed and
# stored in the root directory (/) of the old rootfs (/dev/mmcblk0p2)
# with a filename ending in '*.rootfs.ext4.gz'.
# The boot loader U-Boot is stored at the same location
# with filename ending in '*.sb'

# exit on errors
set -e

# fs check is required before resize
e2fsck -y -f /dev/mmcblk0p2

# shrink current filesystem so that it fits smaller than final two rootfs
resize2fs -f /dev/mmcblk0p2 2032M || true

# re-partition first round - create future /srv partition already at its final location
cat <<EOF | sfdisk /dev/mmcblk0
label: dos
label-id: 0x5452574f
device: /dev/mmcblk0
unit: sectors

/dev/mmcblk0p1 : start=        2048, size=       16384, type=53, bootable
/dev/mmcblk0p2 : start=       20480, size=     4161536, type=83
/dev/mmcblk0p3 : start=     4212736, size=     2097152, type=83
EOF

# format /srv
mkfs.ext4 -F -F /dev/mmcblk0p3

# mount old rootfs and /srv
mount /dev/mmcblk0p2 /mnt
mkdir -p /srv
mount /dev/mmcblk0p3 /srv

# save file we still need from old rootfs
cp /mnt/*.sb /srv
cp /mnt/*.rootfs.ext4.gz /srv

# run pre-install hook if present
[ -x /mnt/install-pre-hook.sh ] && . /mnt/install-pre-hook.sh

# umount again - partition number will change
umount /mnt /srv

# re-partition 2nd time - final partition layout
cat <<EOF | sfdisk /dev/mmcblk0
label: dos
label-id: 0x6d686569
device: /dev/mmcblk0
unit: sectors

/dev/mmcblk0p1 : start=        2048, size=       14336, type=53
/dev/mmcblk0p2 : start=       16384, size=     2097152, type=83
/dev/mmcblk0p3 : start=     2113536, size=     2097152, type=83
/dev/mmcblk0p4 : start=     4210688, size=     2627584, type=5
/dev/mmcblk0p5 : start=     4212736, size=     2097152, type=83
/dev/mmcblk0p6 : start=     6311936, size=      262144, type=83
/dev/mmcblk0p7 : start=     6576128, size=      262144, type=83
EOF

# mount /srv again
mount /dev/mmcblk0p5 /srv

if [ -z "$SKIP_ROOTFS2" ]; then
    # write rootfs partition 2
    zcat /srv/*.rootfs.ext4.gz | dd of=/dev/mmcblk0p3 bs=4M
    resize2fs /dev/mmcblk0p3
fi

# write rootfs partition 1
zcat /srv/*.rootfs.ext4.gz | dd of=/dev/mmcblk0p2 bs=4M
resize2fs /dev/mmcblk0p2

# cleanup U-Boot environment
dd if=/dev/zero of=/dev/mmcblk0 bs=1k count=128 seek=128
dd if=/dev/zero of=/dev/mmcblk0 bs=1k count=128 seek=256

# write U-Boot
sdimage -f /srv/*.sb -d /dev/mmcblk0

# cleanup & reboot
umount /srv
sync

# run pre-install hook if present
[ -x /mnt/install-post-hook.sh ] && . /mnt/install-post-hook.sh

reboot
