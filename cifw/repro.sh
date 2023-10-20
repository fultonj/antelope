#!/bin/bash


pushd ~/ci-framework

ansible-playbook -i localhost, -c local \
                 -e cifmw_target_host=localhost \
                 -e @scenarios/reproducers/validated-architecture-1.yml \
                 -e @validated-architecture-1.yml reproducer.yml
popd
