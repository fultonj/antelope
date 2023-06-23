#!/bin/bash
URL=https://trunk.rdoproject.org/centos9/component/tripleo/current/
RPM_NAME=$(curl $URL | grep python3-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print $1 }')
RPM=$RPM_NAME.rpm
dnf install -y $URL$RPM
tripleo-repos -b wallaby current-tripleo-dev ceph --stream
