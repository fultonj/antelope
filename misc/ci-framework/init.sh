#!/bin/bash

if [[ $1 == 'git' ]]; then
    ssh-keyscan github.com >> ~/.ssh/known_hosts
    git config --global user.email fulton@redhat.com
    git config --global user.name "John Fulton"
    git config --global push.default simple
    git config --global pull.rebase true
    git clone git@github.com:fultonj/antelope.git
fi

if [[ $1 == 'alias' ]]; then
    if [[ ! -e /home/zuul/k8src ]]; then
        echo 'export PASS=$(cat ~/.kube/kubeadmin-password)' > /home/zuul/k8src
        echo 'oc login -u kubeadmin -p $PASS https://api.ocp.openstack.lab:6443' >> /home/zuul/k8src
    fi
    if [[ -e /home/zuul/k8src ]]; then
        echo 'source /home/zuul/k8src' >> ~/.bashrc
    fi
    echo 'alias ll="ls -lhtr"' >> ~/.bashrc
    echo 'alias wtf="oc get events -A --sort-by=.lastTimestamp"' >> ~/.bashrc
fi
