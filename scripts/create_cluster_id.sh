#!/bin/bash

file_path="/var/tmp/clusterID/clusterID"
dir_path="/var/tmp/clusterID"

if [ ! -d "$dir_path" ]; then
  mkdir -p "$dir_path"
  echo "Directory $dir_path has been created."
fi

if [ ! -f "$file_path" ]; then
  /bin/kafka-storage random-uuid > "$file_path"
  echo "Cluster ID has been created..."
fi

chmod 755 "$dir_path"
chmod 644 "$file_path"