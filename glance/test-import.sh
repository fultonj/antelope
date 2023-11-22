#!/bin/bash
source functions.sh

CLEAN=1
WEB=1
GLANCE_CLI=0
PHASED=0

NAME=cirros-$(date +%s)
CIR=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$CIR
STAGE_PATH=/var/lib/glance/os_glance_staging_store
TASK_PATH=/var/lib/glance/os_glance_tasks_store

rbd -p images ls -l
if [ $? -gt 0 ]; then
    echo "Ceph pod did not respond to rbd. Exiting."
    exit 1
fi

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
	    bash cmd-glances.sh ls -lh $STAGE_PATH
	    bash cmd-glances.sh ls -lh $TASK_PATH
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
bash cmd-glances.sh ls -lh $STAGE_PATH
bash cmd-glances.sh ls -lh $TASK_PATH

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
