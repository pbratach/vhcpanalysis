#!/bin/bash

#########################################################################
#
# Copyright (c) by Hitachi, 2025. All rights reserved.
#
# This script checks the system events collected from VSP One Object system
#
##########################################################################

SCRIPT_VERSION="1.0.1.2025-Jul-30"

SYSTEM_EVENTS_FILE_PATTERN="vspo_system_events_7d.json"
INPUT_DIR=${1:-"./cluster"}

OUTPUT_DIR=${2:-"./health_report"}
OUTPUT_FILE="${OUTPUT_DIR}/vspo_system_events_issues.log"

SYSTEM_EVENTS_FILE="${INPUT_DIR}/${SYSTEM_EVENTS_FILE_PATTERN}"

VERBOSE=${3:-0}

################
# Functions
#
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

function usage() {

  echo "\
This script checks the system events collected from VSP One Object system.
Script version: ${SCRIPT_VERSION}
    $0 [<file-with-collected-system-events>] \
"
}

if [[ "$1" == "-h" ]]; then
    usage
    exit
fi

if [[ ! -f ${SYSTEM_EVENTS_FILE} ]]; then
    echo "WARNING: file ${SYSTEM_EVENTS_FILE} doesn't exist"
    SYSTEM_EVENTS_FILE=$(find . | grep -m1 "${SYSTEM_EVENTS_FILE_PATTERN}")
    if [[ -z ${SYSTEM_EVENTS_FILE} || "${SYSTEM_EVENTS_FILE}" == "" ]]; then
        echo "WARNING: Couldn't find ${SYSTEM_EVENTS_FILE_PATTERN} file."
        exit
    fi
fi

echo "Checking System Events"

# Check if output directory exists
if [[ ! -d ${OUTPUT_DIR} ]]; then
    mkdir ${OUTPUT_DIR} # create an output dir
elif [[ -f ${OUTPUT_FILE} ]]; then
    rm -f ${OUTPUT_FILE} # delete an old output file
fi

event_array=$(cat ${SYSTEM_EVENTS_FILE})

num_events=$(echo "${event_array}" | jq '. | length')
if [[ "$num_events" == "0" ]]; then
    echo "No Reported System Events"
    exit
fi

debug "Number of system events: $num_events"

# Filter by unique fields: 
uniq_events=$(echo "${event_array}" | jq '. | reverse | unique_by({severity,subject,message,category,eventTypeId}) | reverse')
num_uniq_events=$(echo "${uniq_events}" | jq '. | length')
debug "Unique events [$num_uniq_events]: ${uniq_events}"

alert_events=$(echo "${uniq_events}" | jq '[.[] | select(.severity == "WARNING" or .severity == "SEVERE")]') 
num_alerts=$(echo "${alert_events}" | jq '. | length')

alerts_count=0

while read -r event; do
  severity=$(echo "$event" | jq -r '.severity' | tr -d " ")
  eventTypeId=$(echo "$event" | jq -r '.eventTypeId' | tr -d " ")
  subject=$(echo "$event" | jq -r '.subject')
  message=$(echo "$event" | jq -r '.message')
  category=$(echo "$event" | jq -r '.category')
  timestamp=$(echo "$event" | jq -r '.timestamp')
  
  SUBJECT="${severity} : ${eventTypeId} : $subject"

  ((alerts_count++))

  LOG_MSG="${severity} : ${eventTypeId} : ${message}"

  # Display an event:
  log "${LOG_MSG}"

done < <(echo "${alert_events}" | jq -c '.[]')

if [[ "${alerts_count}" == "0" ]]; then
    SUMMARY="No issues detected in System Events"
else
    SUMMARY="Detected ${alerts_count} issues in System Events"
fi
log "${SUMMARY}"
