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
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    create --type metric
  write_latency $now $output/${stats_prefix}create-schema.latency

  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    metrics > $output/list.schemas
  write_latency $now $output/${stats_prefix}list-schemas.latency

  # validate that we are reading the schemas properly
  expected="metric,"
  cat $output/list.schemas | sed 's/{//' | sed 's/}//' | sed 's/\\//g' | sed 's/"//g' | awk 'BEGIN{ RS=",";FS=":";}{ printf "%s,",$2}' | tr -d '\r\n' > $output/list.schemas.simple
  assert_schema $expected `cat $output/list.schemas.simple`
fi

if [ "${CREATE_STATS_SCHEMA}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema \
    --api-key $key \
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    create \
    --metric-name server_stats \
    -Fcpu=DOUBLE \
    -Fmemory_used=INTEGER \
    -Fmemory_free=INTEGER \
    -Fmemory_free_percent=DOUBLE
  write_latency $now $output/${stats_prefix}create-stats-schema.latency
fi

# read the schema
now=`get_now`
read_schema > $output/read.schema
write_latency $now $output/${stats_prefix}read-schema.latency

# validate that the schema we read is the same as the schema we created
expected="{\"name\":\"metric\",\"aliases\":[],\"fields\":[{\"name\":\"field\",\"aliases\":[],\"type\":\"STRING\"},{\"name\":\"timestamp\",\"aliases\":[],\"type\":\"LONG\"}],\"timestampPatterns\":[]}"
assert_schema $expected `cat $output/read.schema`

# read the org level schema
now=`get_now`
read_schema_mgmt > $output/read-mgmt.schema
write_latency $now $output/${stats_prefix}read-schema-mgmt.latency
expected="{\"timestampPatterns\":[],\"metricKeys\":[]}"
assert_schema $expected `cat $output/read-mgmt.schema`

# check that we can add a field alias and that is correct. Regresion test from api <-> lambda mismatch
if [ "${ADD_ALIAS_FIELD}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    update --metric-name metric \
    --field-alias "timestamp=ts"
  write_latency $now $output/${stats_prefix}update-schema-field-alias.latency

  read_schema > $output/read2.schema
  write_latency $now $output/${stats_prefix}read-schema_2.latency

  # validate the read
  expected="{\"name\":\"metric\",\"aliases\":[],\"fields\":[{\"name\":\"field\",\"aliases\":[],\"type\":\"STRING\"},{\"name\":\"timestamp\",\"aliases\":[\"ts\"],\"type\":\"LONG\"}],\"timestampPatterns\":[]}"
  assert_schema $expected `cat $output/read2.schema`
fi