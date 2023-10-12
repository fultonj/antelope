#!/bin/bash

pushd ~/ci-framework

ansible-playbook deploy-edpm.yml \
                 -e @~/my-env.yml \
                 --skip-tags packages,boostrap

popd
