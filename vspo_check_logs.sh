#!/bin/bash
#
#########################################################################
#
# Copyright (c) by Hitachi, 2025. All rights reserved.
#
# This script checks the logs collected from VSP One Object system.
#
#########################################################################

SCRIPT_VERSION="1.0.1.2025-Jul-31"

TOOLS_DIR=$(dirname $0)

INPUT_DIR=${1:-"."}
TRIAGE_DATA_DIR="${INPUT_DIR}"
LOG_FILES="_vsp*.log"
KNOWN_ISSUES_FILE="${TOOLS_DIR}/vspo_known_signatures.json"

OUTPUT_DIR=${2:-"./health_report"}
OUTPUT_FILE="${OUTPUT_DIR}/vspo_issues_detected_in_logs.log"

VERBOSE=0

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

###
# Usage
function usage() {
  echo "\
This script checks the logs collected from VSP One Object system.
Script version: ${SCRIPT_VERSION}
    $0 [<dir-with-collected-files>] \
"
}

##############
# Start processing
#
if [[ "$1" == "-h" ]]; then
    usage
    exit
fi

if [[ ! -f ${KNOWN_ISSUES_FILE} ]]; then
    echo "ERROR: cannot find ${KNOWN_ISSUES_FILE} file with known signatures."
    exit
fi

echo "Checking log files for known signature"

# Check if output directory exists
if [[ ! -d ${OUTPUT_DIR} ]]; then
    mkdir ${OUTPUT_DIR} # create an output dir
elif [[ -f ${OUTPUT_FILE} ]]; then
    rm -f ${OUTPUT_FILE} # delete an old output file
fi

known_issues=$(cat "${KNOWN_ISSUES_FILE}")

num_issues=0

while read -r known_issue; do

  issueId=$(echo "${known_issue}" | jq -r '.issueId')
  description=$(echo "${known_issue}" | jq -r '.description')
  severity=$(echo "${known_issue}" | jq -r '.severity')
  signatures=$(echo "${known_issue}" | jq -r '.signatures')

  num_signatures=$(echo "${signatures}" | jq -r '. | length')

  log "Checking issueId=${issueId} for ${num_signatures} signatures"

  num_matched_signatures=0
  signature_count=0
  while read -r signature_element; do

    ((signature_count++))
    signature=$(echo "${signature_element}" | jq -r '.signature')

    if [[ -z ${signature} ]]; then
        log "ERROR: no signature #${signature_count} for issueId ${issueId}"
        continue
    fi

    found=$(grep "${signature}" ${TRIAGE_DATA_DIR}/${LOG_FILES} | wc -l)
    if [[ $found -gt 0 ]]; then
        ((num_matched_signatures++))
    fi
  done < <(echo "${signatures}" | jq -c '.[]')

  if [[ ${num_matched_signatures} -eq ${num_signatures} ]]; then
      ((num_issues++))
      log "${severity} : ${issueId} : ${description} : ${found} entries"
  fi

done < <(echo "${known_issues}" | jq -c '.[]')

log "Detected ${num_issues} issues with known signatures in logs"
echo "Generated ${OUTPUT_FILE} file."

