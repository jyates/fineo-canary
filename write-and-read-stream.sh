#!/usr/bin/env bash
set -e

# ensure we have the output directory
if [ ! -d $output ];then
  mkdir $output
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/functions.sh

function reformat(){
  file=$1
  table=$2
  greater_than=$3
  cat ${file} | sed 's/${table}/metric/g;s/${timestamp}/'"${greater_than}"'/g'
}

function read_api(){
  request=$1
  file=$2
  retries=$3
  wait_time=$4

  read_start=`get_now`

  ${e2e_tools}/bin/sql-runner --jar $client_jdbc_jar \
    --url $read_url --api-key ${API_KEY} --credentials ${READ_CREDENTIALS} \
    --sql-file $request \
    --out $file \
    --retries $retries \
    --wait-time $wait_time

  write_latency ${read_start} ${file}.latency
}

# wait a tick so we have a previous timestamp at which  we are sure no data has been written
old_now=`get_now`
sleep 1
now=`get_now`

# Write some data as a 'bunch' of events
java -cp $client_tools_jar io.fineo.client.tools.Stream \
 --api-key $API_KEY --url $stream_url --credentials-file ${WRITE_CREDENTIALS} \
 --type metric --field field.1 --field timestamp.${now}
 write_latency $now $output/${stats_prefix}stream-batch.write.latency

# first read is slow - kinesis takes a little while to be 'primed'
reformat ${select_star_greater_than} metric $old_now > $output/query1.txt
read_api  $output/query1.txt $output/${stats_prefix}stream-batch.read 10 90

# validate the read
echo "[{ \"timestamp\" : ${now}, \"field\" : \"1\" }]" > $output/stream-batch.expected
${json_matches} $output/stream-batch.read $output/stream-batch.expected

# just a regular read, w/o a write, just for simple e2e read timing
read_api $output/query1.txt $output/stream.read 5 30
${json_matches} $output/stream.read $output/${stats_prefix}stream-batch.expected

echo "--- /stream/events PASS --"

# wait 1 second to definitely get a new timestamp
sleep 1
# update old/now times
old_now=${now}
now=`get_now`

# Write more data as an individual event
java -cp $client_tools_jar io.fineo.client.tools.Stream \
 --api-key $key --url $stream_url --credentials-file ${WRITE_CREDENTIALS} \
 --type metric --field field.2 --field timestamp.${now} \
 --seq # write event as a 'sequential' event
 write_latency $now $output/${stats_prefix}stream-seq.write.latency

# second read should go much faster as kinesis is now 'primed'
reformat ${select_star_greater_than} metric $old_now > $output/query2.txt
read_api  $output/query2.txt $output/${stats_prefix}stream-seq.read 10 30

# validate the read is only the second entry
echo "[{ \"timestamp\" : ${now}, \"field\" : \"2\" }]" > $output/stream-seq.expected
${e2e_tools}/bin/assert_json_matches $output/stream-seq.read $output/stream-seq.expected

echo "--- /stream/event PASS --"
