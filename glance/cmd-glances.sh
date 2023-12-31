#!/bin/bash

SVC=${SVC:-"glance-external"}
CON=glance-api
#SVC=glance-internal
#SVC=glance-single

if [[ -z $@ ]]; then
    CMD="ls -l /var/lib/"
else
    CMD=$@
fi

for POD in $(oc get pods -l service=$SVC --no-headers -o custom-columns=":metadata.name"); do
    echo "> $POD $CMD"
    oc rsh -t --shell='/bin/sh' -c $CON $POD $CMD 2> /dev/null
done
