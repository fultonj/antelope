#!/bin/bash

CLEAN=1
CTL=0

# (re)create PVCs?
PVC=1
# Toy Ceph Cluster?
CEPH=0

if [ $CLEAN -eq 1 ]; then
    pushd ~/install_yamls
    echo "Removing Control Plane"
    make openstack_deploy_cleanup
    if [ $PVC -eq 1 ]; then
        echo -n "Waiting to ensure all Galera pods are have stopped running..."
        while [[ 1 ]]; do
            if [[ $(oc get pods 2> /dev/null | grep -i galera | wc -l) -gt 0 ]]; then
                echo -n "."
                sleep 1
            else
                echo "Galera is not running"
                break
            fi
        done
        pushd ~/install_yamls
        make crc_storage_cleanup
        make crc_storage_cleanup
        popd
    fi
    if [ $CEPH -eq 1 ]; then
	pushd ~/install_yamls
	make ceph_cleanup
	popd
	oc delete secret ceph-conf-files
    fi
    if [ $OPER -eq 1 ]; then
        echo "Removing Operators"
        make openstack_cleanup
    fi
    popd
fi

if [ $CTL -eq 1 ]; then
    if [ $PVC -eq 1 ]; then
        export PVC=1
        bash ../scripts/deploy.sh
        unset PVC
    fi
    pushd ~/install_yamls

    # maria
    make mariadb
    sleep 60
    make mariadb_deploy

    # rabbmit
    make rabbitmq
    sleep 60
    make rabbitmq_deploy

    # infra 
    make infra
    sleep 60

    # memached
    make memcached_deploy
    sleep 60

    # keystone
    make keystone
    sleep 60
    make keystone_deploy
    
    if [ $CEPH -eq 1 ]; then
	make ceph
        if [[ $? -gt 0 ]]; then
            make ceph
        fi
    fi

    popd
fi
