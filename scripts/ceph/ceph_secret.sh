#!/bin/bash

DELETE=1

SSH=$(bash ../ssh_node.sh 0)
KEY=$($SSH "cat /etc/ceph/ceph.client.openstack.keyring | base64 -w 0")
CONF=$($SSH "cat /etc/ceph/ceph.conf | base64 -w 0")

cat <<EOF > ceph_secret.yaml
apiVersion: v1
data:
  ceph.client.openstack.keyring: $KEY
  ceph.conf: $CONF
kind: Secret
metadata:
  name: ceph-conf-files
  namespace: openstack
type: Opaque
EOF

eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443

if [ $DELETE -eq 1 ]; then
    oc delete secret ceph-conf-files
fi

oc create -f ceph_secret.yaml
