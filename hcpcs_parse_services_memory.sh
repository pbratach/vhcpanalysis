#!/bin/bash

# Usage: ./parse_docker_blocks.sh [input_file]
# If no input_file is provided, it reads from standard input

input="${1:-/dev/stdin}"
start_marker="*** docker ps -a ***"
end_marker="*** docker stats --no-stream ***"
capture=false

while IFS= read -r line; do
  if [[ "$line" == "$start_marker" ]]; then
    capture=true
#    echo "$line"
    continue
  fi

  if [[ "$line" == "$end_marker" && "$capture" == true ]]; then
#    echo "$line"
    capture=false
    echo ""  # Print a blank line between blocks
    continue
  fi

  if [[ "$capture" == true ]]; then
    if [[ "$line" == "" || "$line" == "$start_marker" || "$line" == "CONTAINER ID"* ]]; then  
	continue
    else
#        echo "Line is $line"
	img=`echo $line | awk '{print $2}' | awk -F"/" '{print $NF}'`
	cmd=`echo $line | awk '{print $NF}' | awk -F"/" '{print $NF}'`
	uuid=`echo $line | awk '{print substr($0, 0, 12) }'`
#	echo "UUID is $uuid"
	cmem=`grep "$uuid " $input | awk '{print $3, $4, $5, $6, $7}'`
	echo "Image $img Command $cmd is using $cmem memory"
	continue
    fi
  else
    continue
  fi
done < "$input"

