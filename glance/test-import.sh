#!/bin/bash
source functions.sh

CLEAN=1
WEB=0
GLANCE_CLI=1
PHASED=1

NAME=cirros-$(date +%s)
CIR=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$CIR
STAGE_PATH=/var/lib/glance

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
    if [ $GLANCE_CLI -gt 0 ]; then
	if [ $PHASED -gt 0 ]; then
            glance --verbose image-create \
		   --disk-format raw \
		   --container-format bare \
		   --name $NAME
	    ID=$(openstack image show $NAME -c id -f value | strings)
	    glance image-stage --progress --file $CIR $ID
	    bash cmd-glances.sh ls -l $STAGE_PATH
	    glance image-import --import-method glance-direct $ID
	else
            glance --verbose image-create-via-import \
		   --disk-format raw \
		   --container-format bare \
		   --name $NAME \
		   --file $CIR \
		   --import-method glance-direct
	fi
    else
        openstack image create \
                  --disk-format raw \
                  --container-format bare \
                  --file $CIR \
                  --import $NAME
    fi
fi

ID=$(openstack image show $NAME -c id -f value | strings)

until $(openstack image show $NAME -c status -f value | grep -q active); do
    echo -n "."; sleep 1;
done
echo ""

openstack image show $NAME
glance image-show $ID
glance image-tasks $ID
rbd -p images ls -l

if [ $CLEAN -gt 0 ]; then
    openstack image delete $NAME
fi