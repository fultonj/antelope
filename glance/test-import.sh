#!/bin/bash
source functions.sh

CLEAN=1
WEB=0
GLANCE_CLI=1
PHASED=1

TIMEOUT=4
NAME=cirros-$(date +%s)
CIR=cirros-0.5.2-x86_64-disk.img
URL=http://download.cirros-cloud.net/0.5.2/$CIR
STAGE_PATH=/var/lib/glance/os_glance_staging_store

rbd -p images ls -l
if [ $? -gt 0 ]; then
    echo "Ceph pod did not respond to rbd. Exiting."
    exit 1
fi

if [ $WEB -gt 0 ]; then
    # stage and import goes to the same host (does not test distributed image import)
    # distributed image import is only associated with glance-direct (not web-download)
    # web-download does not set os_glance_stage_host to worker_self_reference_url
    glance --verbose image-create-via-import \
       --disk-format qcow2 \
       --container-format bare \
       --name $NAME \
       --uri $URL \
       --import-method web-download
else
    oc rsh -t --shell='/bin/sh' openstackclient stat $CIR > /dev/null 2>&1
    if [ $? -gt 0 ]; then
        oc rsh -t --shell='/bin/sh' openstackclient curl -L $URL -o $CIR
    fi
    if [ $GLANCE_CLI -gt 0 ]; then
	if [ $PHASED -gt 0 ]; then
            # By using phases, stage and import happen on different hosts,
            # so this is the method to use to distributed image import
            glance --verbose image-create \
		   --disk-format qcow2 \
		   --container-format bare \
		   --name $NAME
	    ID=$(openstack image show $NAME -c id -f value | strings)
	    glance image-stage --progress --file $CIR $ID
	    bash cmd-glances.sh ls -lh $STAGE_PATH
	    glance image-import --import-method glance-direct $ID
	else
	    # stage and import go to the same host (does not test distributed image import)
            glance --verbose image-create-via-import \
		   --disk-format raw \
		   --container-format bare \
		   --name $NAME \
		   --file $CIR \
		   --import-method glance-direct
	fi
    else
	# stage and import go to the same host (does not test distributed image import)
        openstack image create \
                  --disk-format raw \
                  --container-format bare \
                  --file $CIR \
                  --import $NAME
    fi
fi

ID=$(openstack image show $NAME -c id -f value | strings)
gsql "SELECT * FROM image_properties WHERE image_id=\"$ID\" AND name='os_glance_stage_host'"
bash cmd-glances.sh ls -lh $STAGE_PATH

STATUS=$(openstack image show $NAME -c status -f value | strings)
echo "$NAME is $STATUS."
if [[ $STATUS != "active" ]]; then
    echo "Sleeping $TIMEOUT seconds"
    sleep $TIMEOUT
fi

openstack image show $NAME
glance image-show $ID
glance image-tasks $ID
rbd -p images ls -l

if [ $CLEAN -gt 0 ]; then
    openstack image delete $NAME
    bash cmd-glances.sh rm -f $STAGE_PATH/$ID > /dev/null 2> /dev/null
fi
