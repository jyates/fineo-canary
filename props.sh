#!/usr/bin/env bash

# disable debugging
set +x
# Fail on errors
set -e

# argument is the directory in which we are working and need to load the rmvrc file
if [ "$#" -gt 0 ]; then
    source $1/.rvmrc
fi

export e2e_tools=$WORKSPACE/tools
export client=$WORKSPACE/client
export client_tools_jar=$WORKSPACE/client/`ls $client/tools*.jar| grep -v tests | grep -v jdbc`
export client_jdbc_jar=$WORKSPACE/client/`ls $client/tools*jdbc.jar`
export queries=$WORKSPACE/queries
export output=$WORKSPACE/job

# urls
export stream_url=https://hvobvxe805.execute-api.us-east-1.amazonaws.com
export read_url=https://` something something `.execute-api.us-east-1.amazonaws.com
