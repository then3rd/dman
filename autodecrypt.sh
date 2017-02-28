#!/bin/bash
PATH=/opt/dman:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games:/opt/bin
source dman-client-config.sh
/usr/bin/dd if=/dev/usbkey bs=2048 skip=1 count=1 status=none| /sbin/cryptsetup luksOpen "${LUKSOPEN}" "${DECRYPT}" --key-file=- && /usr/bin/mount /dev/mapper/"${DECRYPT}" "${MOUNTDIR}"
