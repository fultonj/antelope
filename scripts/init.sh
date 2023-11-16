#!/bin/bash

CLEAN=1

if [ $CLEAN -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    make crc_cleanup
    popd
fi

export CRC=1
bash deploy.sh
unset CRC

export ATTACH=1
bash deploy.sh
unset ATTACH

export PVC=1
bash deploy.sh
unset PVC

export DEPS=1
bash deploy.sh
unset DEPS
