#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/functions.sh

mkdir $output

if [ "${CREATE_SCHEMA}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} --type metric create
  write_latency $now $output/${stats_prefix}create-schema.latency
fi

# read the schema
now=`get_now`
java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
  --url $schema_url --credentials-file ${SCHEMA_CREDENTIALS} --type metric read > $output/read.schema
write_latency $now $output/${stats_prefix}read-schema.latency

# validate that the schema we read is the same as the schema we created
schema=`cat $output/read.schema`
expected="{\"name\":\"metric\",\"aliases\":[],\"timestampPatterns\":[],\"fields\":[{\"name\":\"field\",\"aliases\":[],\"type\":\"STRING\"},{\"name\":\"timestamp\",\"aliases\":[],\"type\":\"LONG\"}]}"

if [ "$schema" != "$expected" ]; then
  echo "Mismatch in schema and expected schema!"
  echo "Expected schema:\n\t$expected"
  echo "Actual schema:\n\t$schema"

  # error!
  exit 1
fi