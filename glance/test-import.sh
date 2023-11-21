#!/bin/bash
source bash-functions.sh

CLEAN=1
NAME=cirros
CIR=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$CIR

rbd -p images ls -l

glance --verbose image-create-via-import \
       --disk-format qcow2 \
       --container-format bare \
       --name $NAME \
       --uri $URL \
       --import-method web-download

until $(openstack image show $NAME -c status -f value | grep -q active); do
    echo -n "."; sleep 1;
done
echo ""

openstack image show $NAME
rbd -p images ls -l

if [ $CLEAN -gt 0 ]; then
    openstack image delete $NAME
fi
