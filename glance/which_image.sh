#!/bin/bash

OP=$(oc get pod -n openstack-operators | grep glance-operator-controller | awk {'print $1'})
IMG=$(oc get pod -n openstack-operators $OP -o yaml | grep quay | tail -1 | awk {'print $2'})
echo $IMG

while getopts ":v" opt; do
    case $opt in
        v) verbose=true ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done
if [ "$verbose" = true ]; then
    podman pull $IMG 2> /dev/null > /dev/null
    podman inspect -f '{{ .Created }}' $IMG
fi
