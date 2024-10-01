#!/bin/bash

file_path="/tmp/clusterID/clusterID"
dir_path="/tmp/clusterID"

if [ ! -d "$dir_path" ]; then
  mkdir -p "$dir_path"
  echo "Directory $dir_path has been created."
fi

if [ ! -f "$file_path" ]; then
  /bin/kafka-storage random-uuid > "$file_path"
  echo "Cluster ID has been created..."
fi