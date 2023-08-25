#!/usr/bin/env python3
# Generate a valid ceph-conf-files secret CR which is called
# ceph_secret_cr.yaml with an arbitrary number of fake ceph
# clusters with multiple cephx key types (RBD, Manila, RGW)
# per cluster. This is useful for generating test data.
#
# Usage:
#   python ceph_secret_cr.py 
#   oc create -f ceph_secret_cr.yaml
#   oc get secret/ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d
#   oc get secret/ceph-conf-files -o json | jq -r '.data."ceph2.conf"' | base64 -d

CLUSTERS=2

import base64
import configparser
import io
import os
import random
import struct
import time
import uuid
import yaml


def get_ceph_conf():
    ips = list()
    subnet = str(random.randint(1, 254))
    for i in range(1, 4):
        ips.append('192.168.' + subnet + '.' + str(i))

    config = configparser.ConfigParser()
    config.add_section('global')
    config.set('global', 'fsid', str(uuid.uuid4()))
    config.set('global', 'mon host', ','.join(ips))

    output_buffer = io.StringIO()
    config.write(output_buffer)
    return output_buffer.getvalue()

def get_ceph_key(user='openstack'):
    # https://github.com/ceph/ceph-deploy/blob/master/ceph_deploy/new.py#L21
    key = os.urandom(16)
    header = struct.pack("<hiih", 1, int(time.time()), 0, len(key))
    client = 'client.' + str(user)

    config = configparser.ConfigParser()
    config.add_section(client)
    config.set(client, 'key', base64.b64encode(header + key).decode('utf-8'))
    config.set(client, 'caps mgr', 'allow *')
    if user == 'openstack':
        config.set(client, 'caps mon', 'profile rbd')
        pools = ['vms', 'volumes', 'images', 'backups']
        config.set(client, 'caps osd', ', '.join(list(
            map(lambda x: 'profile rbd pool=' + x, pools))))
    elif user == 'radosgw':
        config.set(client, 'caps mon', 'allow rw')
        config.set(client, 'caps osd', 'allow rwx')
    elif user == 'manila':
        config.set(client, 'caps mon', "allow r, allow command 'auth del', allow command 'auth caps', allow command 'auth get', allow command 'auth get-or-create'")
        config.set(client, 'caps osd', 'allow rw')
        config.set(client, 'caps mds', 'allow *')

    output_buffer = io.StringIO()
    config.write(output_buffer)
    return output_buffer.getvalue()

def encode_to_base64(input_string):
    encoded_bytes = base64.b64encode(input_string.encode('utf-8'))
    return encoded_bytes.decode('utf-8')


if __name__ == "__main__":
    users = ['openstack', 'radosgw', 'manila']
    yaml_file_path = "ceph_secret_cr.yaml"
    ceph_cr = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": "ceph-conf-files",
            "namespace": "openstack"
        },
        "type": "Opaque",
        "data": {}
    }
    cluster_list = [""]
    for i in range(1, CLUSTERS):
        cluster_list.append(str(i+1))

    for ceph in cluster_list:
        conf = 'ceph' + ceph + '.conf'
        ceph_cr['data'][conf] = encode_to_base64(get_ceph_conf())
        for user in users:
            keyring = 'ceph' + ceph + '.client.' + user + '.keyring'
            ceph_cr['data'][keyring] = encode_to_base64(get_ceph_key(user))

    with open(yaml_file_path, 'w') as yaml_file:
        yaml.dump(ceph_cr, yaml_file, default_flow_style=False)
