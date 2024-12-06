#!/bin/bash

CLEAN=1

if [ $CLEAN -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    make crc_cleanup
    popd
fi

CRC=1 bash deploy.sh
ATTACH=1 bash deploy.sh
PVC=1 bash deploy.sh
DEPS=1 bash deploy.sh

