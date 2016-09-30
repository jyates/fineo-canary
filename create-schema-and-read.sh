#!/usr/bin/env bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/functions.sh

# ensure we have the output directory
if [ ! -d $output ];then
  mkdir $output
fi

if [ "${CREATE_SCHEMA}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} --type metric create
  write_latency $now $output/${stats_prefix}create-schema.latency
fi


# read the schema
now=`get_now`
java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
  --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} \
  --metric-name metric read > $output/read.schema
write_latency $now $output/${stats_prefix}read-schema.latency

# validate that the schema we read is the same as the schema we created
schema=`cat $output/read.schema`
expected="{\"name\":\"metric\",\"aliases\":[],\"fields\":[{\"name\":\"field\",\"aliases\":[],\"type\":\"STRING\"},{\"name\":\"timestamp\",\"aliases\":[],\"type\":\"LONG\"}],\"timestampPatterns\":[]}"

if [ "$schema" != "$expected" ]; then
  echo "Mismatch in schema and expected schema!"
  echo "Expected schema:"
  echo "   $expected"
  echo "Actual schema:"
  echo "   $schema"

  # error!
  exit 1
fi
