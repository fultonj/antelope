#!/bin/bash

CONF="/etc/cinder/cinder.conf.d"
CMD="ls $CONF | xargs -I{} cat $CONF/{}"

for POD in $(oc get pods | grep cinder | awk {'print $1'}); do
    CON=$(oc get pod "$POD" -o jsonpath='{.spec.containers[0].name}')
    if [[ $POD == *0 ]]; then
        echo -e "# POD: $POD\n# ---"
	oc rsh -c $CON $POD sh -c "$CMD"
        echo -e "\n# ---"
    fi
done
