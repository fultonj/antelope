#!/bin/bash

SVC=glance-internal
#SVC=glance-external
#SVC=glance-single

i=0
echo "Which pod do you want logs for?"
for POD in \
    $(oc get pods -l service=$SVC --no-headers -o custom-columns=":metadata.name"); do
    echo $POD
    ((i++))
done
if [ $i -eq 0 ]; then
    echo "No pods were found matching $SVC"
    exit 0
fi
if [ $i -gt 1 ]; then
    read -p "Select the pod by number, (e.g. '0' for ${SVC}-api-0) " NUM
else
    echo "There's only one POD so taking it"
    NUM=0
fi
POD=${SVC}-api-${NUM}
echo $POD
oc logs $POD $@
