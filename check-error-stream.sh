#!/usr/bin/env bash
set -e
set -x

# ensure we have the output directory
if [ ! -d $output ];then
  mkdir $output
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/functions.sh

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Write a 'bad' row and then read the error info back"
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

  # overwrite the READ_CREDENTIALS_PARAM to be username/password
  export READ_CREDENTIALS_PARAM="--username ${USERNAME} --password ${PASSWORD}"
  export WRITE_CREDENTIALS_PARAM="${READ_CREDENTIALS_PARAM}"
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

# wait a tick so we have a previous timestamp at which  we are sure no data has been written
old_now=`get_now`
sleep 1
now=`get_now`

# write a 'bad' row of data
cpu=`current_cpu`
memory_usage > $output/current_memory.usage
readarray memory < $output/current_memory.usage

# Write some data as a 'bunch' of events
java -cp $client_tools_jar io.fineo.client.tools.Stream \
  --api-key $API_KEY \
  ${stream_url} \
  ${WRITE_CREDENTIALS_PARAM} \
  # oops, missing a bad metric name
  --metric-name "server_stats-does-not-exist-for-testing" \
  --field cpu.10 \
  --field timestamp.${now}
 write_latency $now $output/${stats_prefix}error.write.latency

# Wait the minimum amount of time - 60s - for the stream to be flushed
sleep 60

# first read is slow - kinesis takes a little while to be 'primed'
reformat ${select_star_greater_than} "error.stream" ${old_now} > $output/errorRead.txt
output_file=$output/${stats_prefix}error.read
read_api $output/errorRead.txt $output_file 10 90

echo "--- Get Errors PASS --"
exit 0;