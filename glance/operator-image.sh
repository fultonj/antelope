#!/bin/bash

# Update the CSV so it uses a new glance operator image

NEW=quay.io/openstack-k8s-operators/glance-operator:latest
#NEW=quay.io/fultonj/glance-operator:fultonj-test

CSV=$(oc get csv -n openstack-operators | grep glance | awk {'print $1'})
if [[ -z $CSV ]]; then
    echo "Glance operator not found in CSV"
    exit 1
else
    echo "Updating $CSV so it uses $NEW"
fi

echo "Backing up $CSV to glance_operator_csv.json"
oc get csv -n openstack-operators $CSV -o json | \
  jq -r 'del(.metadata.generation, .metadata.resourceVersion, .metadata.uid)'  > glance_operator_csv.json

echo "Creating new version of $CSV with $NEW"
cp glance_operator_csv.json glance_operator_csv_new_img.json
OLD=$(grep image glance_operator_csv.json | grep glance-operator | awk {'print $2'} | sort | uniq | sed -e s/\"//g -e s/,//g)
sed -i s,$OLD,$NEW,g glance_operator_csv_new_img.json
diff -u glance_operator_csv.json glance_operator_csv_new_img.json

oc patch csv -n openstack-operators $CSV --type=merge --patch-file=glance_operator_csv_new_img.json

echo "To restore the OLM version of the glance image use:"
echo "oc patch csv -n openstack-operators $CSV --type=merge --patch-file=glance_operator_csv.json"

echo "Watch new version come up with:"
echo "oc get pods -w -n openstack-operators | grep glance"
