#!/bin/bash
export URL=https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo wget -qO /usr/local/bin/yq $URL
sudo chmod a+x /usr/local/bin/yq

