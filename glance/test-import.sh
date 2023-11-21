#!/bin/bash
source bash-functions.sh

CLEAN=1
WEB=1
GLANCE_CLI=0

NAME=cirros-$(date +%s)
CIR=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$CIR

rbd -p images ls -l

if [ $WEB -gt 0 ]; then
    glance --verbose image-create-via-import \
       --disk-format qcow2 \
       --container-format bare \
       --name $NAME \
       --uri $URL \
       --import-method web-download
else
    oc rsh -t --shell='/bin/sh' openstackclient stat $CIR > /dev/null 2>&1
    if [ $? -gt 0 ]; then
        oc rsh -t --shell='/bin/sh' openstackclient curl $URL -o $CIR
    fi
fi
if [ $GLANCE_CLI -gt 0 ]; then
    glance --verbose image-create-via-import \
              --disk-format raw \
              --container-format bare \
              --name $NAME \
              --file $CIR \
              --import-method glance-direct
else
    openstack image create \
              --disk-format raw \
              --container-format bare \
              --file $CIR \
              --import $NAME
fi

until $(openstack image show $NAME -c status -f value | grep -q active); do
    echo -n "."; sleep 1;
done
echo ""

openstack image show $NAME
rbd -p images ls -l

if [ $CLEAN -gt 0 ]; then
    openstack image delete $NAME
fi
