#!/bin/bash
# GET stestr_results.html after the tempest pod has run

# assuming an SSH tunnel on port 3333 to controller-0 on hypervisor
SSH="ssh zuul@localhost -p 3333"
#JOB_POD_NAME=$($SSH "oc get pod -l batch.kubernetes.io/job-name=tempest-tests -o name")
JOB_POD_NAME=$($SSH "oc get pod -o name | grep tempest | grep -v test-operator")

echo -e "Run this on controller0: \n"
echo -e "  oc debug $JOB_POD_NAME  \n"
echo -e "is it done? [Y]"
# using read only to wait so I can spawn the debug pod and then use it to get the file
read
echo "Getting results..."
DEBUG_POD_NAME=$($SSH "oc get pods | grep tempest-tests | grep -i running | awk {'print \$1'} | head -1")

DIR="/var/lib/tempest/external_files"
# remove 'pod/'
# find the last '-' and remove everything after it
SUB_DIR=$(echo $JOB_POD_NAME | sed -e 's|pod\/||g' -e 's/-[^-]*$//')

$SSH oc rsh $DEBUG_POD_NAME "cat $DIR/$SUB_DIR/stestr_results.html" > stestr_results.html
$SSH oc rsh $DEBUG_POD_NAME "cat $DIR/$SUB_DIR/etc/tempest.conf" > tempest.conf
wc -l stestr_results.html tempest.conf
