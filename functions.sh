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
