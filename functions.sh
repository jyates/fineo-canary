#!/usr/bin/env bash

function get_now() {
  # OSX doesn't have date %N, so we just say the milliseconds are 0
  echo "`date +%s | cut -b1-13`000"
}

function write_latency(){
  local task_end=`get_now`
  local start=$1
  echo `expr $task_end - $start` > $2
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
  local metric_name=${1:-"metric"}
  java -cp ${schema_jar} io.fineo.client.tools.Schema \
    --api-key $key \
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    read --metric-name ${metric_name}
}

function read_schema_mgmt(){
  java -cp ${schema_jar} io.fineo.client.tools.Schema \
    --api-key $key \
    --url $schema_url \
    ${SCHEMA_CREDENTIALS_PARAM} \
    read-mgmt
}

function current_cpu(){
  top -b -n2 -p 1 | fgrep "Cpu(s)" | tail -1 | awk -F'id,'  '{ split($1, vs, ","); v=vs[length(vs)]; sub("%", "", v); printf "%.1f", 100 - v }'
}

# Get the current memory usage
# Outputs into three lines:
# #1 - Used memory
# #2 - Free memory
# #3 - % free memory
function memory_usage(){
  # free -m output is:
  #             total       used       free     shared    buffers     cached
  #Mem:          7983       7828        155          0        351       5698
  # So $1 = Mem, $2 = total, $3 = used, $4 = free
  free -m | awk 'NR==2{printf "%s\n%s\n%.2f\n", $3,$4,$4*100/$2}'
}

# $1 - 'now'
# $2 - cpu
# $3 - used memory
# $4 - free memory
# $5 - free memory percent
function get_write_json(){
  echo "[{ \"timestamp\" : ${1}, \"cpu\" : ${2}, \"memory_used\" : ${3}, \"memory_free\" : ${4}, \"memory_free_percent\" : ${5} }]"
}


function get_rvm(){
  rvm env --path | sed -e 's/\/.*\///'
}

function use_rvm(){
  # ensure rvm can be used as a function
  source "$HOME/.rvm/scripts/rvm"
  # switch to the specified directory - ensures that we properly load the rvmrc and install necessary gems
  cd $1
  local rvm_file=".rvmrc"
  if [[ -s "$rvm_file" ]]; then
    source $rvm_file
    local env_id=`get_rvm`
    bundle install
    cd $DIR
    rvm use $env_id
  else
    echo "rvmrc file (${rvm_file}) is missing/empty!"
    exit 10
  fi
}

function use_rvm_if_possible(){
  local count=$1
  local dir=$2
  if [ "$count" -gt 0 ]; then
    use_rvm $dir
  fi
}

function stashrvm(){
  get_rvm > /tmp/jenkins.canary.stash.rvm
}

function poprvm(){
  if [ -f $job/stash.rvm ];then
    rvm use `cat /tmp/jenkins.canary.stash.rvm`
  fi
}