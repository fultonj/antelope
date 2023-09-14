#!/bin/bash

# return ssh command to reach one of the nodes

SUFFIX=0
if [ ! -z "$1" ]; then
    SUFFIX=$1
fi

IP="192.168.122.10"$SUFFIX
SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/install_yamls/out/edpm/ansibleee-ssh-key-id_rsa"

echo "$SSH cloud-admin@$IP"
