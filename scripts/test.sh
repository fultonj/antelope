#!/bin/bash

OVERVIEW=0
CEPH=1
GLANCE=1
GLANCE_DEL=1
IMPORT_RAW=0
RMIMG=0
CINDER=1
VOL_FROM_IMAGE=1
NOVA_CONTROL_LOGS=0
NOVA_COMPUTE_LOGS=0
PRINET=0
VM=0
CONSOLE=0
VOL_ATTACH=0
NOVA_INSTANCE_LOGS=0
PUBNET=0
FLOAT=0
SEC=0
SSH=0
PET=0
RGW=0
MANILA=0

# node0
NODES=0

IMG_NAME=cirros
VOL_NAME=vol1
VM_NAME=vm1
VOL_IMG_NAME="${VOL_NAME}-${IMG_NAME}"

export OS_CLOUD=default
export OS_PASSWORD=12345678

if [ $OVERVIEW -eq 1 ]; then
   openstack endpoint list
   openstack network agent list
   openstack compute service list
fi

function run_on_mon {
    $(bash ssh_node.sh) "sudo cephadm shell -- $1" 2> /dev/null
}

if [ $GLANCE -eq 1 ]; then
    # make sure the glance HTTP service is available
    GLANCE_ENDPOINT=$(openstack endpoint list -f value -c "Service Name" -c "Interface" -c "URL" | grep glance | grep public | awk {'print $3'})
    if [[ $(curl -s $GLANCE_ENDPOINT | grep Unavailable | wc -l) -gt 0 ]]; then
        echo "curl $GLANCE_ENDPOINT returns unavailable (glance broken?)"
        curl -s $GLANCE_ENDPOINT
        exit 1
    fi
    if [ $GLANCE_DEL -eq 1 ]; then
        # clean up previoius image and volume from image to test again
        for VOL in $(openstack volume list -c Name -f value | grep $VOL_IMG_NAME); do
            openstack volume delete $VOL
        done
        for IMG in $(openstack image list -c Name -f value | grep $IMG_NAME); do
            openstack image delete $IMG
        done
    fi
    IMG=cirros-0.5.2-x86_64-disk.img
    URL=http://download.cirros-cloud.net/0.5.2/$IMG
    RAW=$(echo $IMG | sed s/img/raw/g)
    if [ ! -f $RAW ]; then
	if [ ! -f $IMG ]; then
	    echo "Could not find qemu image $IMG; downloading a copy."
	    curl -L -# $URL > $IMG
	fi
        if [ $IMPORT_RAW -eq 1 ]; then
	    echo "Could not find raw image $RAW; converting."
            if [[ ! -e /bin/qemu-img ]]; then
                sudo dnf install qemu-img -y
            fi
	    qemu-img convert -f qcow2 -O raw $IMG $RAW
        fi
    fi
    openstack image list
    if [ $CEPH -eq 1 ]; then
        echo " --------- Ceph images pool --------- "
        run_on_mon "rbd -p images ls -l"
        if [ $IMPORT_RAW -eq 1 ]; then
	    echo "Importing $RAW image into Glance in format raw"
	    openstack image create $IMG_NAME --container-format bare --disk-format raw < $RAW
        else
            echo "Importing $IMG image into Glance in format qcow2 to test Glance image conversion"
            openstack image create $IMG_NAME --container-format bare --disk-format raw --file $IMG --import
            sleep 3
        fi
    else
	echo "Importing $IMG image into Glance in format qcow2"
        openstack image create $IMG_NAME --container-format bare --disk-format qcow2 < $IMG
    fi
    if [ ! $? -eq 0 ]; then 
        echo "Could not import image. Aborting"; 
        exit 1;
    fi
    if [ $CEPH -eq 1 ]; then
        echo "Listing Glance Ceph Pool and Image List"
        run_on_mon "rbd -p images ls -l"
    fi
    openstack image list
    if [ $CEPH -eq 1 ]; then
        # https://bugzilla.redhat.com/show_bug.cgi?id=1672680
        GLANCE_ID=$(openstack image show $IMG_NAME -f value -c id)
        openstack image set $GLANCE_ID --property hw_disk_bus=scsi
    fi
    if [ $RMIMG -eq 1 ]; then
        rm -f cirros-0.5.2-x86_64-disk.*
    fi
fi

if [ $CINDER -eq 1 ]; then
    echo " --------- Ceph cinder volumes pool --------- "
    run_on_mon "rbd -p volumes ls -l"
    openstack volume list
    if [ $VOL_FROM_IMAGE -eq 1 ]; then
        echo "Creating 8 GB Cinder volume from $IMG_NAME"
        GLANCE_ID=$(openstack image show $IMG_NAME -f value -c id)
        openstack volume create --size 8 $VOL_IMG_NAME --image $GLANCE_ID
    else
        echo "Creating empty 1 GB Cinder volume"
        openstack volume create --size 1 $VOL_NAME
    fi
    sleep 5
    echo "Listing Cinder Ceph Pool and Volume List"
    openstack volume list
    run_on_mon "rbd -p volumes ls -l"
fi

if [ $NOVA_CONTROL_LOGS -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    oc get pods | grep nova | grep -v controller
    for POD in $(oc get pods | grep nova | grep -v controller | awk {'print $1'}); do
        echo $POD
        echo "~~~"
        oc logs $POD | grep ERROR | grep -v ERROR_FOR_DIVISION_BY_ZERO
        echo "~~~"
    done
fi

if [ $NOVA_COMPUTE_LOGS -eq 1 ]; then
    SSH_CMD=$(bash ssh_node.sh 1)
    $SSH_CMD "sudo grep ERROR /var/log/containers/nova/nova-compute.log"
    $SSH_CMD "date"
fi

if [ $PRINET -eq 1 ]; then
    openstack network create private --share
    openstack subnet create priv_sub --subnet-range 192.168.0.0/24 --network private
fi

if [ $VM -eq 1 ]; then
    if [[ $(openstack hypervisor list -f value | wc -l) -eq 0 ]]; then
        # https://issues.redhat.com/browse/OSPRH-319
        echo "Attempting to discover Nova hosts"
        eval $(crc oc-env)
        oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
        oc rsh nova-cell0-conductor-0 nova-manage cell_v2 discover_hosts
        openstack hypervisor list
    fi
    if [[ $(openstack hypervisor list -f value | wc -l) -eq 0 ]]; then
        echo "'openstack hypervisor list' empty after 'nova-manage cell_v2 discover_hosts'"
        exit 1
    fi
    FLAV_ID=$(openstack flavor show c1 -f value -c id)
    if [[ -z $FLAV_ID ]]; then
        openstack flavor create c1 --vcpus 1 --ram 256
    fi
    NOVA_ID=$(openstack server show $VM_NAME -f value -c id)
    if [[ -z $NOVA_ID ]]; then
        openstack server create --flavor c1 --image cirros --nic net-id=private $VM_NAME
    fi
    openstack server list
    if [[ $(openstack server list -c Status -f value) == "BUILD" ]]; then
        echo "Waiting one 30 seconds for building server to boot"
        sleep 30
        openstack server list
    fi
    if [ $CEPH -eq 1 ]; then
        echo "Listing Nova Ceph Pool"
        run_on_mon "rbd -p vms ls -l"
    fi
fi

if [ $CONSOLE -eq 1 ]; then
    openstack console log show $VM_NAME
fi

if [ $VOL_ATTACH -eq 1 ]; then
    VM_ID=$(openstack server show $VM_NAME -f value -c id)
    VOL_ID=$(openstack volume show $VOL_NAME -f value -c id)
    openstack server add volume $VM_ID $VOL_ID
    sleep 2
    openstack volume list
    # openstack server remove volume $VM_ID $VOL_ID
fi

if [ $NOVA_INSTANCE_LOGS -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    openstack server show $VM_NAME
    ID=(openstack server show $VM_NAME -f value -c id)
    oc get pods | grep nova | grep -v controller
    for POD in $(oc get pods | grep nova | grep -v controller | awk {'print $1'}); do
        echo $POD
        echo "~~~"
        # oc logs $POD | grep $ID
        echo "~~~"
    done
    for I in $(seq 0 $NODES); do
        echo "edpm-compute-$I"
        echo "~~~"
        SSH_CMD=$(bash ssh_node.sh $I)
        $SSH_CMD "sudo grep $ID /var/log/containers/nova/nova-compute.log"
        $SSH_CMD "date"
        echo "~~~"
    done
fi

if [ $PUBNET -eq 1 ]; then
    openstack network create public --external --provider-network-type flat --provider-physical-network datacentre
    openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public
    openstack router create priv_router
    openstack router add subnet priv_router priv_sub
    openstack router set priv_router --external-gateway public
fi

if [ $FLOAT -eq 1 ]; then
    IP=$(openstack floating ip list -f value -c "Floating IP Address")
    if [[ -z $IP ]]; then
        openstack floating ip create public
        IP=$(openstack floating ip list -f value -c "Floating IP Address")
        echo $IP
    else
        echo $IP
    fi
    if [[ ! -z $IP ]]; then
        openstack server add floating ip $VM_NAME $IP
    fi
    openstack server show $VM_NAME
    openstack server list
fi

if [ $SEC -eq 1 ]; then
    PROJECT_ID=$(openstack server show $VM_NAME -c project_id -f value)
    if [[ ! -z $PROJECT_ID ]]; then
        SEC_ID=$(openstack security group list --project $PROJECT_ID -f value -c ID)
        openstack security group rule create \
                  --protocol tcp --ingress --dst-port 22 $SEC_ID
    fi
fi

if [ $SSH -eq 1 ]; then
    if [[ ! -f /usr/bin/sshpass ]]; then
        sudo dnf -y install sshpass
    fi
    IP=$(openstack floating ip list -f value -c "Floating IP Address")
    sshpass -p gocubsgo ssh cirros@$IP "uname -a"
    sshpass -p gocubsgo ssh cirros@$IP "lsblk"
fi

if [ $PET -eq 1 ]; then
    echo "The following Glance image is backed by Ceph"
    openstack image list
    IMG_ID=$(openstack image show cirros -c id -f value)
    run_on_mon "rbd -p images ls -l"

    echo "Creating a volume based on $IMG_ID"
    openstack volume create --size 8 cirros-volume --image $IMG_ID
    run_on_mon "rbd -p volumes ls -l"

    VOL_ID=$(openstack volume show -f value -c id cirros-volume)
    openstack server create --flavor c1 --volume $VOL_ID --nic net-id=private pet-vm
    openstack server list
fi

if [ $RGW -eq 1 ]; then
    echo "Testing the following object-store endpoint"
    RGW_ENDPOINTS=0
    for ID in $(openstack endpoint list -f value | grep object-store | awk {'print $1'}); do
        openstack endpoint show $ID
        RGW_ENDPOINTS=$[$RGW_ENDPOINTS +1]
    done
    if [[ $RGW_ENDPOINTS -eq 0 ]]; then
        echo "No RGW endpoints found. Did you run rgw.sh?"
        exit 1
    fi
    # The openstackclient has access to the storage network
    echo "Attempting to list object continainers from within the openstackclient pod"
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    oc rsh openstackclient openstack container list
    COUNT=5
    echo "Creating $COUNT swift containers and observing the RGW buckets.index increment"
    for I in $(seq 0 $COUNT); do
        oc rsh openstackclient openstack container create mydir$I
        sleep 1
        run_on_mon "ceph df" | egrep "POOL|rgw"
    done
    echo "Deleting the $COUNT swift containers"
    oc rsh openstackclient openstack container list
    for I in $(seq 0 $COUNT); do
        oc rsh openstackclient openstack container delete mydir$I
    done
    oc rsh openstackclient openstack container list
    run_on_mon "ceph df" | egrep "POOL|rgw"
fi

if [ $MANILA -eq 1 ]; then
    echo "openstack share service list"
    oc rsh openstackclient openstack share service list
    echo "openstack share pool list"
    oc rsh openstackclient openstack share pool list
    SHARE_ID=$(oc rsh openstackclient openstack share list -f value -c ID | tr -d "[:space:]")
    if [[ -z $SHARE_ID ]]; then
        echo "Creating CephFS share"
        oc rsh openstackclient openstack share type create default false
        oc rsh openstackclient openstack share create cephfs 1
        SHARE_ID=$(oc rsh openstackclient openstack share list -f value -c ID | tr -d "[:space:]")
    else
        echo "CephFS share ID is $SHARE_ID"
    fi
    echo "Getting subvolume ID from Ceph with 'ceph fs subvolume ls cephfs'"
    SUB_VOL_ID=$(echo $(run_on_mon "ceph fs subvolume ls cephfs") | jq -r '.[0].name')
    if [[ -z $SUB_VOL_ID ]]; then
        echo "Empty output from 'ceph fs subvolume ls cephfs'"
        exit 1
    else
        echo "Subvolume ID is $SUB_VOL_ID"
    fi
    echo -e "\nConfirming that share ID has subvolume ID\n"
    oc rsh openstackclient openstack share show $SHARE_ID | grep $SUB_VOL_ID
fi
