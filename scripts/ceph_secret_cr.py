#!/usr/bin/env python3
# Generate a valid looking ceph-conf-files secret CR called
# ceph_secret_cr.yaml with an arbitrary number of fake ceph
# clusters. This is useful for generating test data.
#
# Usage:
#   python ceph_secret_cr.py 
#   oc create -f ceph_secret_cr.yaml
#   oc get secret/ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d
#   oc get secret/ceph-conf-files -o json | jq -r '.data."ceph2.conf"' | base64 -d

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

def get_ceph_key():
    # https://github.com/ceph/ceph-deploy/blob/master/ceph_deploy/new.py#L21
    key = os.urandom(16)
    header = struct.pack("<hiih", 1, int(time.time()), 0, len(key))
    pools = ['vms', 'volumes', 'images', 'backups']

    config = configparser.ConfigParser()
    config.add_section('client.openstack')
    config.set('client.openstack', 'key', base64.b64encode(header + key).decode('utf-8'))
    config.set('client.openstack', 'caps mgr', 'allow *')
    config.set('client.openstack', 'caps mon', 'profile rbd')
    config.set('client.openstack', 'caps osd', ', '.join(list(
        map(lambda x: 'profile rbd pool=' + x, pools))))

    output_buffer = io.StringIO()
    config.write(output_buffer)
    return output_buffer.getvalue()

def encode_to_base64(input_string):
    encoded_bytes = base64.b64encode(input_string.encode('utf-8'))
    encoded_string = encoded_bytes.decode('utf-8')
    return encoded_string


if __name__ == "__main__":
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
    for ceph in ["", 2]:
        conf = 'ceph' + str(ceph) + '.conf'
        keyring = 'ceph' + str(ceph) + '.client.openstack.keyring'
        ceph_cr['data'][conf] = encode_to_base64(get_ceph_conf())
        ceph_cr['data'][keyring] = encode_to_base64(get_ceph_key())

    with open(yaml_file_path, 'w') as yaml_file:
        yaml.dump(ceph_cr, yaml_file, default_flow_style=False)
