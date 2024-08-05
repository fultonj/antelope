#!/bin/bash

if [[ ! -d ~/test-python ]]; then
    echo "~/test-python directory is missing."
    echo "Please 'make setup_molecule' in ci-framework directory."
    exit 1
fi

TOK=$(cat ../ci_token)
oc login --token=$TOK --server=https://api.ci.l2s4.p1.openshiftapps.com:6443 > /dev/null
if [[ $? -gt 0 ]]; then
    echo "Get a new ../ci_token"
    exit 1
fi

if [[ -f ~/ansible.log ]]; then
    NEW=ansible.log-$(date +"%Y%m%d%H%M%S")
    mv ~/ansible.log logs/$NEW
    gzip logs/$NEW
fi

if [[ $1 == "deep_clean" ]]; then
    # https://ci-framework.readthedocs.io/en/latest/quickstart/99_FAQ.html#deep-cleaning
    PBOOK=reproducer-clean.yml
    ARGS="--tags deepscrub"
fi

if [[ -z $1 ]]; then
    # after deep clean
    PBOOK=reproducer.yml
    # ARGS="--skip-tags packages"
    # if brand new, do not pass any tags (uncomment)
    ARGS="--flush-cache"
fi

pushd ci-framework
. ~/test-python/bin/activate
time ansible-playbook \
     -i custom/inventory.yml \
     -e cifmw_target_host=hypervisor-1 \
     -e @scenarios/reproducers/va-hci.yml \
     -e @scenarios/reproducers/networking-definition.yml \
     -e @custom/default-vars.yml \
     -e @custom/hci.yml \
     -e @custom/secrets.yml \
     -e @custom/my-overrides.yml \
     $PBOOK $ARGS
deactivate
popd
