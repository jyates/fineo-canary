#!/usr/bin/env bash

set -e
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/functions.sh

# ensure we have the output directory
if [ ! -d $output ];then
  mkdir $output
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Write and read schema"
  echo "$0 [-h|--help] [user] [skip_url]"
  echo "Arguments:"
  echo "  user       Enale username/password mode."
  echo "  skip_url   Skips specifying the URL for requests."
  echo " -h, --help  Show this help."
  exit 0;
fi

# if we enable the user mode
if [ "$1" = "user" ] || [ "$2" = "user" ]; then
  if [ "${USERNAME}x" = "x" ] || [ "${PASSWORD}x" = "x" ]; then
    echo "Missing username/password, but user mode enabled!"
    exit 1
  fi

  # overwrite the SCHEMA_CREDENTIALS_PARAM to be username/password
  export SCHEMA_CREDENTIALS_PARAM="--username ${USERNAME} --password ${PASSWORD}"
fi

if [ "$1" = "skip_url" ] || [ "$2" = "skip_url" ]; then
  read_url=""
  schema_url=""
  stream_url=""
else
  schema_url="--url $schema_url"
  read_url="--url $read_url"
  stream_url="--url $stream_url"
fi

# Execution
############
if [ "${CREATE_SCHEMA}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    ${schema_url} \
    ${SCHEMA_CREDENTIALS_PARAM} \
    create --type metric
  write_latency $now $output/${stats_prefix}create-schema.latency

  java -cp ${schema_jar} io.fineo.client.tools.Schema --api-key $key \
    ${schema_url} \
    ${SCHEMA_CREDENTIALS_PARAM} \
    metrics > $output/list.schemas
  write_latency $now $output/${stats_prefix}list-schemas.latency

  # validate that we are reading the schemas properly
  expected="metric,"
  # something of the form {"idToMetricName":{"_ff1729680826":"metric","_ff2222":"antohermetric"}}
  # 1. replace } globaly
  # 2. repalce any \ globally
  # 3. replace any quotes, globally
  # 4. remove {"idToMetricName":{
  # 5. split the fields on ":" and records on ","
  # 6. replace line feed characters which awk is injecting (after the last record)
  cat $output/list.schemas | sed 's/}//g' | sed 's/\\//g' | sed 's/"//g' | awk 'BEGIN{ FS=":{"}{print $2}' | awk 'BEGIN{RS=","; FS=":";}{printf "'%s',", $2}'|tr -d '\r\n' > $output/list.schemas.simple
  assert_schema $expected `cat $output/list.schemas.simple`
fi

if [ "${CREATE_STATS_SCHEMA}" = "true" ]; then
  now=`get_now`
  java -cp ${schema_jar} io.fineo.client.tools.Schema \
    --api-key $key \
    ${schema_url} \
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
    ${schema_url} \
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
