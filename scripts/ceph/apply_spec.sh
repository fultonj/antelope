#!/bin/bash
CID=$(./cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).container_id' | sed s/\"//g);
podman cp /root/ceph_spec.yml $CID:/tmp/ceph_spec.yml
podman cp /etc/ceph/ceph.client.admin.keyring $CID:/etc/ceph/ceph.client.admin.keyring
NAME=$(./cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).name' | sed s/\"//g);
./cephadm enter --name $NAME -- ceph orch apply --in-file /tmp/ceph_spec.yml
./cephadm enter --name $NAME -- rm /etc/ceph/ceph.client.admin.keyring /tmp/ceph_spec.yml
