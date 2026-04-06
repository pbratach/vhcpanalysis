#!/bin/bash
#
#########################################################################
#
# Copyright (c) by Hitachi, 2025. All rights reserved.
#
# This script checks traige data collected from VSP One Object system
#
#########################################################################

TOOL_VERSION="1.0.2.2025-Aug-06"


TRIAGE_DATA_DIR="."
OUTPUT_DIR="${TRIAGE_DATA_DIR}/health_report"
OUTPUT_FILE="${OUTPUT_DIR}/vspo_process_triage_data.log"

INPUT_FILE=""
INPUT_DIR="${TRIAGE_DATA_DIR}/cluster"

VERBOSE=0

TOOLS_DIR=$(dirname $0)

################
# Functions

function usage() {
    thisfilename=$(basename "$0")

    echo "\
This script processes the triage data collected from VSP One Object system.
Version: ${TOOL_VERSION}
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

if [[ ! -d ${OUTPUT_DIR} ]]; then
    mkdir ${OUTPUT_DIR}
fi

###############
# Unpack triage tar files
#
${TOOLS_DIR}/vspo_triage_unpack.sh -f ${INPUT_FILE}

###############
# Check against ATD file (the HRO-style)
#
FILE_CHK="${TOOLS_DIR}/ATD/vsp1o_alerts_def.json"
COLLECTED_JSON_PATTERN="vsp1o_collection_def_autogen_"
PROCESSED_FILE="${OUTPUT_DIR}/vsp1o_atd_report"

if [[ "${FILE_CHK}" != "" && -f ${FILE_CHK} ]]; then
    FILE_CHK_OPT="-f ${FILE_CHK}"
else
    log "ERROR: cannot find check-definitions file: ${FILE_CHK}"
    log "Skipping ATD processing"
fi

VERBOSE_OPT=""
if [[ "$VERBOSE" == "1" ]]; then
     VERBOSE_OPT="-v info"
elif [[ "$VERBOSE" == "2" ]]; then
     VERBOSE_OPT="-v debug"
fi

COLLECTED_JSON=$(find ${INPUT_DIR} | grep "${COLLECTED_JSON_PATTERN}")
if [[ -f ${COLLECTED_JSON} ]]; then
    debug "${TOOLS_DIR}/process_telemetry_alerts.sh -c ${COLLECTED_JSON} -o ${PROCESSED_FILE} ${FILE_CHK_OPT} ${VERBOSE_OPT}"
    ${TOOLS_DIR}/process_telemetry_alerts.sh -c ${COLLECTED_JSON} -o ${PROCESSED_FILE} ${FILE_CHK_OPT} ${VERBOSE_OPT}
else
    log "WARNING: Cannot find a file with ${COLLECTED_JSON_PATTERN} pattern in ${INPUT_DIR} directory"
    log "Skipping ATD processing"
fi

#################
# Check system events 
# echo "Check System Events"
${TOOLS_DIR}/vspo_check_system_events.sh ${INPUT_DIR} ${OUTPUT_DIR}

#################
# Check logs for known signatures
# echo "Check logs for known signatures"
${TOOLS_DIR}/vspo_check_logs.sh ${INPUT_DIR} ${OUTPUT_DIR}
