#!/bin/bash

declare -a REPOS=(
    install_yamls
    dataplane-operator
    edpm-ansible
)
PUSH=1
GIT_USER=openstack-k8s-operators

for REPO in ${REPOS[@]}; do
    pushd ~/$REPO

    if [[ $(git branch --show-current) != main ]]; then
        # If on the non-main branch, stash it and checkout main
        git stash
        git checkout main
    fi
    if [[ $(git remote | grep upstream | wc -l) -eq 0 ]]; then
        # Add remote from original repository in my forked repository
        URL="git@github.com:${GIT_USER}/${REPO}.git"
        git remote add upstream $URL
        git fetch upstream
        git remote -v
    fi
    # Update my fork from original repo to keep up with their changes
    git pull upstream main
    if [ $PUSH -eq 1 ]; then
        git push
    fi
    git log --oneline --since="1 week ago"
    git show --summary
    popd
done
