#!/usr/bin/env bash

function get_now() {
  # OSX doesn't have date %N, so we just say the milliseconds are 0
  echo "`date +%s | cut -b1-13`000"
}

function write_latency(){
  task_end=`get_now`

  start=$1
  file=$2
  echo `expr $task_end - $start` > $file
}

function assert_schema(){
  if [ "${1}" != "${2}" ]; then
    echo "Mismatch in schema and expected schema!"
    echo "Expected schema:"
    echo "   ${1}"
    echo "Actual schema:"
    echo "   ${2}"

    # error!
    exit 1
  fi
}

function read_schema(){
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} \
    read --metric-name metric
}

function read_schema_mgmt(){
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} \
    read-mgmt
}