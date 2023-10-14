#!/bin/bash

pushd ~/ci-framework
ansible-playbook cleanup-edpm.yml -e @~/my-env.yml
# rm -rf ~/ci-framework-data
for I in $(seq 0 2); do
    make -C $HOME/install_yamls/devsetup edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=$I;
done
# make -C $HOME/install_yamls/devsetup # crc_cleanup
popd

# cleanup-edpm.yml basically just deletes these directories
# https://github.com/openstack-k8s-operators/ci-framework/blob/main/ci_framework/roles/ci_setup/tasks/directories.yml
