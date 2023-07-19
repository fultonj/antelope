#!/bin/bash

IPAM=1
NET=0
PRE=1
BOOT=1
SINGLE_OSD=0
SSH_KEYS=1
SPEC=1
CEPHX=1
NODES=2

RSA="/home/$USER/install_yamls/out/edpm/ansibleee-ssh-key-id_rsa"
OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
IP=192.168.122.100

if [ $IPAM -eq 1 ]; then
    # https://github.com/openstack-k8s-operators/install_yamls/pull/373
    # EDPM nodes get their IPs from IPAM so look them up
    # and then update the ceph_spec.yml with the new values
    STORAGE_NET=172.18.0
    MGMT_NET=192.168.122
    for I in $(seq $NODES -1 0); do
        # loop goes backwards so that MON_IP for first host is defined
        MON_IP=$(ssh -i $RSA $OPT root@$MGMT_NET.10${I} \
                     ip a | grep $STORAGE_NET | awk {'print $2'} \
                     | awk 'BEGIN { FS = "/" } ; { print $1 }')
        sed -i s/$STORAGE_NET.10${I}/$MON_IP/g ceph_spec.yml
    done
    echo "The MON IP for bootstrap is: $MON_IP"
fi

if [ $NET -eq 1 ]; then
    # install os-net-config on edpm-compute-0 to configure network isolation
    # wallaby verseions are used to be compatible with adoption
    scp -i $RSA $OPT wallaby_repos.sh root@$IP:/tmp/wallaby_repos.sh
    ssh -i $RSA $OPT root@$IP "bash /tmp/wallaby_repos.sh"
    ssh -i $RSA $OPT root@$IP "dnf install -y os-net-config openvswitch"
    scp -i $RSA $OPT network.sh root@$IP:/tmp/network.sh
    ssh -i $RSA $OPT root@$IP "bash /tmp/network.sh"
fi

if [ $PRE -eq 1 ]; then
    URL=https://raw.githubusercontent.com/ceph/ceph/quincy/src/cephadm/cephadm
    for I in $(seq 0 $NODES); do
	IPL="192.168.122.10${I}"
	scp -i $RSA $OPT hosts root@$IP:/etc/hosts
	scp -i $RSA $OPT ceph_spec.yml root@$IP:/root/ceph_spec.yml
	scp -i $RSA $OPT initial_ceph.conf root@$IP:/root/initial_ceph.conf
	ssh -i $RSA $OPT root@$IPL "curl --silent --remote-name --location $URL"
	ssh -i $RSA $OPT root@$IPL "chmod +x cephadm"
	ssh -i $RSA $OPT root@$IPL "mkdir -p /etc/ceph"
	ssh -i $RSA $OPT root@$IPL "dnf install podman lvm2 jq -y"
    done
fi

if [ $BOOT -eq 1 ]; then
    $(bash ../ssh_node.sh) "./cephadm bootstrap --config initial_ceph.conf --single-host-defaults --skip-monitoring-stack --skip-dashboard --skip-mon-network --mon-ip $MON_IP"
fi

if [ $SINGLE_OSD -eq 1 ]; then
    # If only deploying a single OSD node and not using spec, then add OSDs like this
    $(bash ../ssh_node.sh) "./cephadm shell -- ceph orch apply osd --all-available-devices"
fi

if [ $SSH_KEYS -eq 1 ]; then
    scp -i $RSA $OPT root@$IP:/etc/ceph/ceph.pub .
    URL=$(cat ceph.pub | curl -F 'f:1=<-' ix.io)
    rm ceph.pub

    ANSIBLE_HOST_KEY_CHECKING=False ansible \
            -i 192.168.122.101,192.168.122.102 all \
            -u root -b --private-key $RSA \
            -m ansible.posix.authorized_key -a "user=root key=$URL"
fi

if [ $SPEC -eq 1 ]; then
    scp -i $RSA $OPT apply_spec.sh root@$IP:/root/apply_spec.sh
    $(bash ../ssh_node.sh) "bash /root/apply_spec.sh"
fi

if [ $CEPHX -eq 1 ]; then
    scp -i $RSA $OPT cephx.sh root@$IP:/root/cephx.sh
    $(bash ../ssh_node.sh) "bash /root/cephx.sh"
    $(bash ../ssh_node.sh) "ls -l /etc/ceph/"
fi
