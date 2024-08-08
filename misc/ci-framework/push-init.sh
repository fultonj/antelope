#!/bin/bash

SSH="ssh -A zuul@big -t ssh -A zuul@controller-0"
URL=https://raw.githubusercontent.com/fultonj/antelope/main/misc/ci-framework/init.sh 
$SSH "curl $URL -o ~/init.sh"
$SSH "chmod 755 ~/init.sh"
# $SSH "bash ~/init.sh alias"
# $SSH "bash ~/init.sh git"
