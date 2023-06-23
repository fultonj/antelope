#!/bin/bash

# Add $COUNT disks to EDPM compute by suffix
# If no suffix is provided then it assumes the suffix 0

COUNT=2
if [ $# -eq 0 ]; then
    SUFFIX=0
else
    SUFFIX=$1
fi
VM=edpm-compute-${SUFFIX}
DISK_DIR=$(realpath ~/.crc/machines/crc/)

echo "Adding $COUNT disks to $VM"
for J in $(seq 1 $(( $COUNT )) ); do
    L=$(echo $J | tr 0123456789 abcdefghij)
    if [[ -e $DISK_DIR/$VM-disk-$L.img ]]; then
	# delete if a disk is left over from old VM
	sudo rm -f $DISK_DIR/$VM-disk-$L.img
    fi
    sudo qemu-img create -f raw $DISK_DIR/$VM-disk-$L.img 10G
    sudo virsh attach-disk $VM --config $DISK_DIR/$VM-disk-$L.img vd$L
done

# `virsh attach-disk --live` only works for 1 disk
# To attach >1 disk use --config and destroy/start
# https://listman.redhat.com/archives/libvirt-users/2018-December/msg00043.html

sudo virsh destroy $VM
sudo virsh start $VM

