#!/bin/bash

pushd ~/ci-framework
ansible-playbook cleanup-edpm.yml -e @~/my-env.yml
rm -rf ~/ci-framework-data
make -C $HOME/install_yamls/devsetup crc_cleanup edpm_compute_cleanup
popd
