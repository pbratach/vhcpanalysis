#!/bin/bash
#
# ========================================================================
# Copyright (c) by Hitachi, 2025. All rights reserved.
# ========================================================================
#
# This script unpacks logs collected by vspo_collect_triage_data.sh from VSP One Object system 
#
##############################

SCRIPT_VERSION="1.0.1.2025-Aug-06"

INPUT_FILE=""
INPUT_DIR="./logs"
OUTPUT_DIR="./cluster"

################
# Functions

function usage() {
    thisfilename=$(basename "$0")

    echo "\
Unpack triage data package collected from VSP One Object system by vspo_collect_triage_data.sh
Version: ${SCRIPT_VERSION}
Usage: $thisfilename [options]
  -f <input-filename>     Required    File with collected triage data
  -v                      Optional    Verbose mode
  -h                      Optional    This message
 e.g. ./$thisfilename -f vspo_collect_triage_data_2025_08_06T13_41_56Z.tar \
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
    echo "$1" | tee -a ${OUTPUT_FILE}
}

##############################
#
# Check the input parameters:
#
function getOptions() {
    while getopts "f:i:o:vh" opt; do
        case $opt in
            f) INPUT_FILE=${OPTARG}
                ;;

            i) INPUT_DIR=${OPTARG}
                ;;

            o) OUTPUT_DIR=${OPTARG}
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

if [[ -z ${INPUT_FILE} || "${INPUT_FILE}" == "" ]]; then
    echo "Missing input filename. Use -f option."
    usage
    exit
fi

if [[ ! -f ${INPUT_FILE} ]]; then
    echo "ERROR: file ${INPUT_FILE} not found. Verify -f option."
    usage
    exit
fi

echo "Untar ${INPUT_FILE}"
tar -xvf "${INPUT_FILE}"
if [ $? -ne 0 ]; then
    echo "Failed to untar ${INPUT_FILE} file."
    exit
fi

echo "Unpack files in ${INPUT_DIR}"

if [[ ! -d ${OUTPUT_DIR} ]]; then
    mkdir ${OUTPUT_DIR}
fi

for TAR_FILE in ${INPUT_DIR}/*.tar.xz ; do
     echo "tar -xf ${TAR_FILE} -C ${OUTPUT_DIR}/"
     tar -xvf ${TAR_FILE} -C ${OUTPUT_DIR}/
done 

GZIP_FILES=$(find ${OUTPUT_DIR} | grep "\.gz")
echo "gz files: ${GZIP_FILES}"

for GZIP_FILE in "${OUTPUT_DIR}/*/*.gz" ; do
    echo "gunzip -v ${GZIP_FILE}"
    gunzip -v ${GZIP_FILE}
done

# Delete ${INPUT_DIR} if it indeed has some tar.xz files (safety measure):
num_tar_files=$(ls -1 ${INPUT_DIR}/*.tar.xz | wc -l)
if [[ $num_tar_files -lt 10 && $num_tar_files -gt 5 ]]; then
    rm -rf ${INPUT_DIR}/
fi

echo "Triage data unpacked into ${OUTPUT_DIR} directory"
