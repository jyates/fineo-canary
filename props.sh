#!/usr/bin/env bash

# argument is the directory in which we are working and need to load the rmvrc file
if [ "$#" -gt 0 ]; then
    source $1/.rvmrc
fi

# $1 = the credentials parameter to check
function get_credentials(){
  if [ "x" != "x${1}" ]; then
    echo "--credentials-file ${1}"
  else
    echo "--static-key ${AWS_ACCESS_KEY_ID} --static-secret ${AWS_SECRET_ACCESS_KEY}"
  fi
}

export e2e_tools=$WORKSPACE/tools
export client=$WORKSPACE/client
# ls here apparently gives the whole directory path, when run on jenkins....
export client_tools_jar=`ls $client/tools*.jar| grep -v tests | grep -v jdbc`
export client_jdbc_jar=`ls $client/tools*jdbc.jar`
export queries=$WORKSPACE/queries
export output=$WORKSPACE/job

export select_star_greater_than=${queries}/select-star-from-table-where-timestamp-greater-than.txt
export json_matches=${e2e_tools}/bin/assert_json_matches

# schema properties
export schema_jar=${client_tools_jar}
export stats_prefix=canary-
export SCHEMA_CREDENTIALS=${WRITE_CREDENTIALS}
export key=${API_KEY}


# sort out how credentials work
export WRITE_CREDENTIALS_PARAM=`get_credentials ${WRITE_CREDENTIALS}`
export READ_CREDENTIALS_PARAM=`get_credentials ${READ_CREDENTIALS}`
export SCHEMA_CREDENTIALS_PARAM=`get_credentials ${SCHEMA_CREDENTIALS}`