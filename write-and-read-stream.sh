#!/usr/bin/env bash
set -e
set -x

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
  cat ${file} | sed 's/${table}/'"${table}"'/g;s/${timestamp}/'"${greater_than}"'/g'
}

function read_api(){
  request=$1
  file=$2
  retries=$3
  wait_time=$4

  read_start=`get_now`

  ${e2e_tools}/bin/sql-runner --jar $client_jdbc_jar \
    --url $read_url --api-key ${API_KEY} \
    ${READ_CREDENTIALS_PARAM} \
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

# do a simple read of the catalog - regression catch for validating schema reads
catalog_query=$output/catalog_query.sql
echo "SELECT '' AS \`Interim zero-row result set\` FROM INFORMATION_SCHEMA.CATALOGS LIMIT 0" > $catalog_query
read_api $catalog_query "${output}/catalog.read" 1 10


# get the actual event data to write
cpu=`current_cpu`
memory_usage > $output/current_memory.usage
readarray memory < $output/current_memory.usage

# Write some data as a 'bunch' of events
java -cp $client_tools_jar io.fineo.client.tools.Stream \
  --api-key $API_KEY --url $stream_url \
  ${WRITE_CREDENTIALS_PARAM} \
  --metric-name server_stats \
  --field cpu.${cpu} \
  --field memory_used.${memory[0]} \
  --field memory_free.${memory[1]} \
  --field memory_free_percent.${memory[2]} \
  --field timestamp.${now}
 write_latency $now $output/${stats_prefix}stream-batch.write.latency

# first read is slow - kinesis takes a little while to be 'primed'
reformat ${select_star_greater_than} server_stats $old_now > $output/query1.txt
output_file=$output/${stats_prefix}stream-batch.read
read_api $output/query1.txt $output_file 10 90

# validate the read
get_write_json $now $cpu ${memory[0]} ${memory[1]} ${memory[2]} > $output/stream-batch.expected
${json_matches} $output_file $output/stream-batch.expected

# just a regular read, w/o a write, just for simple e2e read timing
output_file=$output/${stats_prefix}stream.read
read_api $output/query1.txt $output_file 5 30
${json_matches} $output_file $output/stream-batch.expected

echo "--- /stream/events PASS --"

# wait 1 second to definitely get a new timestamp
sleep 1
# update old/now times
old_now=${now}
now=`get_now`

# Write more data as an individual event
java -cp $client_tools_jar io.fineo.client.tools.Stream \
  --api-key $API_KEY --url $stream_url \
  ${WRITE_CREDENTIALS_PARAM} \
  --metric-name server_stats \
  --field cpu.${cpu} \
  --field memory_used.${memory[0]} \
  --field memory_free.${memory[1]} \
  --field memory_free_percent.${memory[2]} \
  --field timestamp.${now} \
  --seq # write event as a 'sequential' event
 write_latency $now $output/${stats_prefix}stream-seq.write.latency

# second read should go much faster as kinesis is now 'primed'
reformat ${select_star_greater_than} server_stats $old_now > $output/query2.txt
output_file=$output/${stats_prefix}stream-seq.read
read_api  $output/query2.txt $output_file 10 30

# validate the read is only the second entry
get_write_json $now $cpu ${memory[0]} ${memory[1]} ${memory[2]} > $output/stream-seq.expected
${json_matches} $output_file $output/stream-seq.expected

echo "--- /stream/event PASS --"
