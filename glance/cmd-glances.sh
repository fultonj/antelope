#!/bin/bash

SVC=${SVC:-"glance-internal"}
#SVC=glance-external
#SVC=glance-single

if [[ -z $@ ]]; then
    CMD="ls -l /var/lib/"
else
    CMD=$@
fi

for POD in $(oc get pods -l service=$SVC --no-headers -o custom-columns=":metadata.name"); do
    echo "> $POD $CMD"
    oc rsh -t --shell='/bin/sh' $POD $CMD 2> /dev/null
done
