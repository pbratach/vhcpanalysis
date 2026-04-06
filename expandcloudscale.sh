#!/bin/bash
#
# Expands CloudScale logs.
# Works on ZIP log packages or already-unzipped tar/tgz files in the current
# working directory.
#
#    Usage: expandcloudscale [zipfile.zip]...
#
# If no parameters are given, all tar/tgz files in the current directory will
# be extracted and then deleted.
#
# If one or more parameters are given, each must be a zip file with a name ending in ".zip".
# The script will create a directory based on the name of each zip file, and will then expand
# the logs into that newly created directory.  The zip files will not be deleted.
#
# Modified by Zielinski and ChatGPT - February, 2024
#
################################################################################
# Examples:
#
# ./expandcloudscale
#     Expands all tgz log packages in the current directory and then delete them.
#
# ./expandcloudscale logs_1611677432171.20210126.0817.zip
#     Expands the names zip file into a newly created directory with the same name (minus the .zip, of course)

function printusage {
   SCRIPTNAME=$(basename $0)
   echo "USAGE: $SCRIPTNAME [zipfile.zip]..."
   echo "       With no parameters, $SCRIPTNAME will expand all tgz and tar.gz files in the current"
   echo "       directory, and then delete those tar/tgz files."
   echo "       If one or more parameters are given, each must be a zip file ending in '.zip'."
   echo "       For each zip file specified, a directory will be created and the zip file will"
   echo "       be expanded inside that newly created directory."
}

if [ "$1" = "-h" ] || [ "$1" = "-?" ]; then
   printusage
   exit
fi

# This function extracts the specified tar file.
function extracttars {
   shopt -s nullglob
   # File names like log_172_18_56_102_.tar.gz or the legacy name hci_log_172_18_56_102_.tar.gz
   if [[ $1 == hci_* ]]; then
     node=$(echo $1 | cut -s -d _ -f 6 -)
   else
     node=$(echo $1 | cut -s -d _ -f 5 -)
   fi
   # File name like f33-1-b0-vm17.tgz
   if [ x$node == "x" ]; then
     node=$(echo $1 | cut -d . -f 1 - | cut -s -d - -f 4 -)
   fi

   # Neither of filename patterns above, so just strip off the extension
   if [ x$node == "x" ]; then
     node=$(echo $1 | cut -d . -f 1 -)
   fi

   mkdir -p ${node}
   echo "   expanding log file ${i}..."
   tar Cxzf ./${node} ${1}
   # remove the tar file:
   rm -f ${1}
   # remove empty files and directories:
   find ${node} -type f -size 0 -delete
   find ${node} -mindepth 1 -type d -empty -delete
   # fix permissions:
   find ${node} -type d -exec chmod 777 {} \;
   find ${node} -type f -exec chmod 666 {} \;
}

# only needed if using parallel
# export -f extracttars

# If there are commandline arguments, we extract only the zip file(s) specified.
if [ $# -ne 0 ]; then
   zips=$*

   # VERIFY all zip files given are good:
   if [ $# -eq 1 ]; then
      echo "Verifying input file..."
   else
      echo "Verifying input files..."
   fi
   for zipfile in $zips
   do
      # Make sure all input files end in .zip:
      if [ $(echo ${zipfile} | grep ".zip$" | wc -l) != 1 ]; then
         echo "ERROR: Filename (${zipfile}) must end in .zip.  Exiting."
         exit
      fi

      # Verify each zip file exists.
      if [ ! -f ${zipfile} ]; then
         echo "ERROR: File ${zipfile} does not exist.  Exiting."
         exit
      fi

      if [ $(UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE /usr/bin/unzip -tq ${zipfile} | grep "No errors detected in" | wc -l) != 1 ]; then
         echo "ERROR: File ${zipfile} does not appear to be a healthy zip file.  Exiting."
         exit
      fi
   done

   # At this point, any input files have been validated.  Time to expand.....

   for zipfile in ${zips}; do
      # Make a directory into which we extract the logs.
      DIRNAME=$(echo ${zipfile} | sed -e 's/.zip$//' | sed 's/logs/HCPCSLogs/g' | sed -e 's/.*-\([0-9]\{8\}\.[0-9]\{4\}\)$/HCPCSLogs-\1/')
      # If a directory already exists, warn and exit:
      if [ -d ${DIRNAME} ]; then
        echo "ERROR: directory ${DIRNAME} already exists.  Maybe these logs are already expanded."
        echo "       exiting..."
        continue
      fi
      mkdir ${DIRNAME}
      chmod 777 ${DIRNAME}
      echo "Creating directory ${DIRNAME}"
      cd ${DIRNAME}

      # Do the unzipping:
      UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE /usr/bin/unzip -uo ../${zipfile}

      # Extract every tar file and then do housekeeping:
      for i in *gz; do
         extracttars $i
      done

      cd ..
   done

else
   # Extract every tar file and then do housekeeping:
   NumofGZfiles=$(ls *gz 2>/dev/null | wc -l)
   if [ ${NumofGZfiles} != 0 ]; then
      for i in *gz; do
         extracttars $i
      done
   else
      echo "ALERT: There were no tar.gz or tgz files found in the current directory."
      printusage
   fi
fi

