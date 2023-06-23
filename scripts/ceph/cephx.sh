#!/bin/bash

for P in vms volumes images; do ./cephadm shell -- ceph osd pool create $P; done
for P in vms volumes images; do ./cephadm shell -- ceph osd pool application enable $P rbd; done

./cephadm shell -- ceph auth add client.openstack mgr 'allow *' mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=vms, allow rwx pool=volumes, allow rwx pool=images'

./cephadm shell -- ceph auth get client.openstack > /etc/ceph/ceph.client.openstack.keyring
./cephadm shell -- ceph config generate-minimal-conf > /etc/ceph/ceph.conf
