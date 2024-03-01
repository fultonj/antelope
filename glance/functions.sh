#!/bin/bash

openstack() {
    oc rsh -t --shell='/bin/sh' openstackclient openstack $@
}

ceph() {
    #oc rsh -t --shell='/bin/sh' ceph ceph $@
    ssh compute-0 "sudo cephadm shell -- ceph $@"
}

rbd() {
    # oc rsh -t --shell='/bin/sh' ceph rbd $@
    ssh compute-0 "sudo cephadm shell -- rbd $@"
}

glance() {
    # From opentsackclient pod's `.config/openstack/clouds.yaml`
    # END=https://keystone-public-openstack.apps-crc.testing
    END=https://keystone-public-openstack.apps.ocp.openstack.lab
    oc rsh -t --shell='/bin/sh' openstackclient glance --os-auth-url $END --os-project-name admin --os-username admin --os-password 12345678 --os-user-domain-name default --os-project-domain-name default $@
}

function gsql() {
    oc exec -it -c galera pod/openstack-galera-0 -- mysql -uroot -p12345678 -e "use glance; $@"
}
