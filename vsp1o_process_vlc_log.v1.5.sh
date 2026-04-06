#!/bin/bash
#
#########################################################################
#
# Copyright (c) by Hitachi, 2025. All rights reserved.
#
# This script processes vlc logs collected from VSP One Object system
# Author:
#     Paul Bratach
#
# Version 1.4:
#   Updated for VSP1O v3.2 vlc 
# Version 1.5:
#   Added error checking before unpacking tar files
#   Added color to log messages
#   Updated POST_PROCESSING_SCRIPT to use symbolic link to latest version
#########################################################################

TOOL_VERSION="1.5.0.2026-Feb-27"

CURRENT_DIR=$(pwd)

OUTPUT_DIR="."
#OUTPUT_DIR="test1"
OF_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="${CURRENT_DIR}/vspo_process_vlc.${OF_TIMESTAMP}.log"

INPUT_FILE=""
INPUT_DIR="${CURRENT_DIR}/cluster"

#POST_PROCESSING_SCRIPT="/home/pbratach/bin/vspo_post_processing.sh"
POST_PROCESSING_SCRIPT="/usr/local/bin/post-diaginspector.sh"

VERBOSE=0

TOOLS_DIR=$(dirname "$0")

################
# Functions

function usage() {
    thisfilename=$(basename "$0")

    echo "\
This script processes the vlc data collected from VSP One Object system.
Version: ${TOOL_VERSION}
Usage: $thisfilename [options]
  -f <input-filename>     Required    File with collected triage data
  -v                      Optional    Verbose mode
  -h                      Optional    This message
 e.g. ./$thisfilename -f  05233669.k8s-hp-3255_27_08_2025_20_03_25.tar.20250828.0750.gz \
	 3.2 filename: 05374912.vsp1o_log_collection.20251223.0900.tar \
"
}

function debug() {
    if [[ $VERBOSE -gt 0 ]]; then
        echo "$1" 
    fi
}

###
# Log 
function log() {
    if [ "$1" = "E" ]; then
        echo -e "\033[0;31m$2\033[0m" | tee -a ${OUTPUT_FILE} 2>&1
    elif [ "$1" = "I" ]; then
        echo -e "\033[0;32m$2\033[0m" | tee -a ${OUTPUT_FILE} 2>&1
    fi
}

##############################
#
# Check the input parameters:
#
function getOptions() {
    while getopts "f:vh" opt; do
        case $opt in
            f) INPUT_FILE=${OPTARG}
                ;;

            v)  VERBOSE=1
                ;;

            *)  usage
                exit 0
                ;;
        esac
    done
}

##### Start
#
getOptions "$@"

log I "Script version ${TOOL_VERSION}, started at ${OF_TIMESTAMP}"

if [[ -z ${INPUT_FILE} || "${INPUT_FILE}" == "" ]]; then
    echo "Missing an input filename. Use -f option."
    usage
    exit
fi

if [[ ! -f ${INPUT_FILE} ]]; then
    echo "ERROR: file ${INPUT_FILE} not found. Verify -f option."
    usage
    exit
fi

ifregex="_(.*).tar"
if [[ $INPUT_FILE =~ $ifregex ]]; then
	IF_TIMESTAMP="${BASH_REMATCH[1]}"
	log I "Extracted timestamp is $IF_TIMESTAMP" 
else
	log I "No timestamp found in the log file $INPUT_FILE" 
fi

if [[ ! -d ${CURRENT_DIR}/${IF_TIMESTAMP} ]]; then
    mkdir -p ${CURRENT_DIR}/${IF_TIMESTAMP}
fi

if [[ "$VERBOSE" == "1" ]]; then
	log I "Contents of ${CURRENT_DIR}/${IF_TIMESTAMP}" 
	ls -lR ${CURRENT_DIR}/${IF_TIMESTAMP}
fi

###############
# Unpack log tar file
#
log I "Unpacking tar file ${INPUT_FILE} into ${CURRENT_DIR}/${IF_TIMESTAMP}" 
tar xf ${INPUT_FILE} -C ${CURRENT_DIR}/${IF_TIMESTAMP}
log I " "

# Change directory to the unpacked log tar file
cd ${CURRENT_DIR}/${IF_TIMESTAMP}

# Check the log collection log
log I "Displaying the nodes logs that were collected, please review `ls *.log` for addtional log collection information" 
grep Successfully *.log
log I " " 

# Change directory to the cluster subdirectory
cd ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster
if [[ "$VERBOSE" == "1" ]]; then
	pwd
	ls -l
fi

# Unpack the log tar and directories.tar.gz files for each node
for i in $(ls *.tar.gz | sort -t '_' -k 1n -k 5.1,5.4n -k 4.1,4.2n -k 3.1,3.2n -k 8.1,8.2n -k 6.1,6.2n -k 7.1,7.2n -k 8.1,8.2n); do 
	nodeNum=$(echo $i | awk -F '[-_]' '{print $4}'); 
	if [ -f "$i" ]; then 
		log I "Unpacking tar log file $i for node $nodeNum"
	       	mkdir -p $nodeNum
	       	tar xf $i -C $nodeNum
		if [ -f "${nodeNum}/vsp-object-node-${nodeNum}/directories.tar.gz" ]; then
	       		log I "  Unpacking directories.tar.gz in $i for node $nodeNum"
	       		tar --exclude=*.mount -xf $nodeNum/vsp-object-node-${nodeNum}/directories.tar.gz -C $nodeNum/vsp-object-node-${nodeNum}
			log I "    Removing original compressed tar files ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster/$i and ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster/$nodeNum/vsp-object-node-${nodeNum}/directories.tar.gz"
			rm $i
		       	rm ${nodeNum}/vsp-object-node-${nodeNum}/directories.tar.gz
			for j in $(ls ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster/$nodeNum/vsp-object-node-${nodeNum}/var/log/storage/archived); do 
				log I "      Unzipping archived logs in ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster/$nodeNum/vsp-object-node-${nodeNum}/var/log/storage/archived/$j";
				cd ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster/$nodeNum/vsp-object-node-${nodeNum}/var/log/storage/archived/$j;
				for k in $(ls *.gz); do 
					gunzip $k; 
				done; 
			cd ${CURRENT_DIR}/${IF_TIMESTAMP}/cluster;
			done; 
		else
			log E "Could not find directories.tar.gz in $i for node $nodeNum"
		fi
       	else 
		log E "Could not find tar log file $i for node $nodeNum"
	fi; 
done


# Call the script to post-process the logs
if [[ -f ${POST_PROCESSING_SCRIPT} ]]; then
	log I "Calling the post-processing script ${POST_PROCESSING_SCRIPT}" 
	${POST_PROCESSING_SCRIPT}
else
	log E "Could not find the post-processing script ${POST_PROCESSING_SCRIPT}" 
fi

# Change back to the original directory
cd ${CURRENT_DIR}

# Open the permissions on the logs
log I "Opening the permissions on the logs"
bash /usr/local/bin/fix_permissions

# Chown on the logs to the current user to remove root ownership of the files
#chown -R $USER .*

END_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
log I "Script completed at ${END_TIMESTAMP}"
