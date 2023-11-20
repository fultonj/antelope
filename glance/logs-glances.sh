#!/bin/bash

SVC=glance-internal
#SVC=glance-external
#SVC=glance-single

echo "Which pod do you want logs for?"
for POD in \
    $(oc get pods -l service=$SVC --no-headers -o custom-columns=":metadata.name"); do
    echo $POD
done
read -p "Select the pod by number, (e.g. '0' for ${SVC}-api-0) " NUM
POD=${SVC}-api-${NUM}
echo $POD
oc logs $POD $@
