#!/bin/bash
# GET stestr_results.html after the tempest pod has run

# assuming an SSH tunnel on port 3333 to controller-0 on hypervisor
SSH="ssh zuul@localhost -p 3333"
JOB_POD_NAME=$($SSH "oc get pod -l batch.kubernetes.io/job-name=tempest-tests -o name")
echo -e "Run this on controller0: \n"
echo -e "  oc debug $JOB_POD_NAME  \n"
echo -e "is it done? [Y]"
# using read only to wait so I can spawn the debug pod and then use it to get the file
read
DEBUG_POD_NAME=$($SSH "oc get pods | grep tempest-tests | grep -i running | awk {'print \$1'} | head -1")
$SSH oc rsh $DEBUG_POD_NAME "cat /var/lib/tempest/external_files/tempest-tests/stestr_results.html" > stestr_results.html
$SSH oc rsh $DEBUG_POD_NAME "cat /var/lib/tempest/external_files/tempest-tests/etc/tempest.conf" > tempest.conf
wc -l stestr_results.html tempest.conf
