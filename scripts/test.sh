#!/bin/bash

OVERVIEW=0
CEPH=0
CINDER=0
GLANCE=1
RMIMG=1
NOVA_CONTROL_LOGS=0
NOVA_COMPUTE_LOGS=0
PRINET=1
VM=1
CONSOLE=0
VOL_ATTACH=0
NOVA_INSTANCE_LOGS=0
PUBNET=0
FLOAT=0
SEC=0
SSH=0
PET=0

# node0
NODES=0

VOL_NAME=vol1
VM_NAME=vm1

export OS_CLOUD=default
export OS_PASSWORD=12345678

if [ $OVERVIEW -eq 1 ]; then
   openstack endpoint list
   openstack hypervisor list
   openstack network agent list
   openstack compute service list
fi

function run_on_mon {
    $(bash ssh_node.sh) "./cephadm shell -- $1" 2> /dev/null
}

if [ $CINDER -eq 1 ]; then
    echo " --------- Ceph cinder volumes pool --------- "
    run_on_mon "rbd -p volumes ls -l"
    openstack volume list

    echo "Creating 1 GB Cinder volume"
    openstack volume create --size 1 $VOL_NAME
    sleep 10

    echo "Listing Cinder Ceph Pool and Volume List"
    openstack volume list
    run_on_mon "rbd -p volumes ls -l"
fi

if [ $GLANCE -eq 1 ]; then
    # make sure the glance HTTP service is available
    GLANCE_ENDPOINT=$(openstack endpoint list -f value -c "Service Name" -c "Interface" -c "URL" | grep glance | grep public | awk {'print $3'})
    if [[ $(curl -s $GLANCE_ENDPOINT | grep Unavailable | wc -l) -gt 0 ]]; then
        echo "curl $GLANCE_ENDPOINT returns unavailable (glance broken?)"
        curl -s $GLANCE_ENDPOINT
        exit 1
    fi

    IMG=cirros-0.5.2-x86_64-disk.img
    URL=http://download.cirros-cloud.net/0.5.2/$IMG
    RAW=$(echo $IMG | sed s/img/raw/g)
    if [ ! -f $RAW ]; then
	if [ ! -f $IMG ]; then
	    echo "Could not find qemu image $IMG; downloading a copy."
	    curl -L -# $URL > $IMG
	fi
	echo "Could not find raw image $RAW; converting."
        if [[ ! -e /bin/qemu-img ]]; then
            sudo dnf install qemu-img -y
        fi
	qemu-img convert -f qcow2 -O raw $IMG $RAW
    fi
    openstack image list
    if [ $CEPH -eq 1 ]; then
        echo " --------- Ceph images pool --------- "
        run_on_mon "rbd -p images ls -l"
	echo "Importing $RAW image into Glance in format raw"
	openstack image create cirros --disk-format=raw --container-format=bare < $RAW
    else
        openstack image list
	echo "Importing $IMG image into Glance in format qcow2"
	openstack image create cirros --disk-format=qcow2 --container-format=bare < $IMG
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
        GLANCE_ID=$(openstack image show cirros -f value -c id)
        openstack image set $GLANCE_ID --property hw_disk_bus=scsi
    fi
    if [ $RMIMG -eq 1 ]; then
        rm -f cirros-0.5.2-x86_64-disk.*
    fi
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
    $SSH_CMD "grep ERROR /var/log/containers/nova/nova-compute.log"
    $SSH_CMD "date"
fi

if [ $PRINET -eq 1 ]; then
    openstack network create private --share
    openstack subnet create priv_sub --subnet-range 192.168.0.0/24 --network private
fi

if [ $VM -eq 1 ]; then
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
        $SSH_CMD "grep $ID /var/log/containers/nova/nova-compute.log"
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
