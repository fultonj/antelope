#!/bin/bash

pushd ~/ci-framework
if [[ ! -d venv ]]; then
    mkdir venv
    python -m venv venv
fi
source venv/bin/activate 

pip list

ansible-playbook deploy-edpm.yml \
                 -e @~/my-env.yml

# --skip-tags packages,boostrap,infra,test

deactivate
popd
