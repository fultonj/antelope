#!/bin/bash

DT=gamma

if [[ $DT == "delta" ]]; then
    PATHS=(
        examples/dt/uni04delta/control-plane/nncp/
        examples/dt/uni04delta/control-plane/
        examples/dt/uni04delta/edpm-pre-ceph/nodeset/
        examples/dt/uni04delta/edpm-pre-ceph/
        examples/dt/uni04delta/
        examples/dt/uni04delta/deployment/
    )
elif [[ $DT == "gamma" ]]; then
    PATHS=(
        examples/va/hci/control-plane/nncp/
        examples/va/hci/control-plane/
        examples/va/hci/edpm-pre-ceph/nodeset/
        examples/va/hci/edpm-pre-ceph/deployment
        examples/va/hci/
        examples/va/hci/deployment/
    )
fi

for BPATH in ${PATHS[@]}; do
    echo "---"
    echo "# next: $BPATH"
    echo "---"
    kustomize build $BPATH
done
