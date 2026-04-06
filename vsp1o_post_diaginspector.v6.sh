#!/bin/bash
# VSP1O - diagcollector/diaginspector analysis
# Change directory to where the diaginspector output is stored
#
# Version 1:
#   Counting the total number of S3 calls in istio s3 logs
#   Calculate Total number of S3 calls in s3-gateway istio-proxy logs
#   Calcualte Total number of downstream_remote_disconnect errors in S3 calls in s3-gateway istio-proxy logs
#   Remove the downstream_remote_disconnect errors in istio s3 logs
#   Count the number of S3 calls ignoring downstream_remote_disconnect errors in istio s3 logs
#   Breakdown of S3 Calls, Status and Size
#
# Version 1.2:
#   Calculate the total size, min, max and avg time for all S3 status codes ignoring downstream_remote_disconnect errors
#
# Version 1.2.3:
#   If all-s3-gateway-istio-proxy.txt exists, rename it to all-s3-gateway-istio-proxy.txt.timestamp
#
# Version 1.3:
#   Added check for WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application" error
#
# Version 1.4:
#   Added display of the serial number and versions of VSP1O and Kubernetes
#   Updated check for Warning KI-1
#   Added display of issues if nodes, namespaces, pods, crojobs, deployments, statefulsets, replicasets, daemonsets, pvc, pv are not in good state
# Version 1.4.1:
#   Started formatting the wc output numbers with commas
#   Display bucket information in vspo_telemetry_report.log
# Version 1.4.2.1:
#   Started formatting the wc output numbers with commas 
#   Display bucket information in vspo_telemetry_report.log
#   Add error checking for existence of log files
#   Add the START_TIME and END_TIME and calculate how long the script ran
#
# Version 6
#  Removed display of telemtry information, display name of telemetry file to manually review
#  Updated to ignore log file checks for vlc logs
######################################################
export LC_ALL="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"

# Display the version of the script
echo " "
echo "Script version 1.6 (03/27/2026)"

# Record the start time using the %s format (seconds since the epoch)
START_TIME=$(date +%s)
echo "Script started at: $(date)"
echo " "

if [ -f all-s3-gateway-istio-proxy.txt ]; then
	echo "WARNING: File all-s3-gateway-istio-proxy.txt already exists, backing up old version"
	mv all-s3-gateway-istio-proxy.txt all-s3-gateway-istio-proxy.txt.`stat -c %y all-s3-gateway-istio-proxy.txt | cut -d'.' -f1 | tr -d '-' | tr -d ' ' | tr -d ':'`
fi

# Get VSP1O serial number
echo -e "\033[0;32mVSP1O serial number \033[0m"
output=$(find . -name vspo_serial_number_get.log)
if [[ -n "$output" ]]; then
	find . -name vspo_serial_number_get.log -exec grep value {} \; | awk '{print $2}' | sed 's/^/      /'
else
	echo -e "\033[0;31mCould not find file vspo_serial_number_get.log. This is normal if these logs were collected by the vlc command.\033[0m"
fi
echo " "

# Get VSP1O Kubernetes versions
echo -e "\033[0;32mVSP1O Kubernetes versions\033[0m"
output=$(find . -name vspo_kubectl_version_short.log )
if [[ -n "$output" ]]; then
	find . -name vspo_kubectl_version_short.log -exec cat {} \; | sed 's/^/      /'
else
	echo -e "\033[0;31mCould not find file vspo_kubectl_version_short.log. This is normal if these logs were collected by the vlc command.\033[0m"
fi
echo " "

# Get VSP1O region(s) versions
echo -e "\033[0;32mVSP1O region(s) version \033[0m"
output=$(find . -name vspo_galaxy_info.log)
if [[ -n "$output" ]]; then
	find . -name vspo_galaxy_info.log -exec grep -A1 name {} \; | sed 's/--//g'
else
	echo -e "\033[0;31mCould not find file vspo_galaxy_info.log. This is normal if these logs were collected by the vlc command.\033[0m"
fi
echo " "

# Get diagcollector telemetry report
echo -e "\033[0;32mVSP1O diagcollector telemtry report \033[0m"
output=$(find . -name vspo_telemetry_report.log)
if [[ -n "$output" ]]; then
	echo -e "\033[0;32mPlease review telemetry file $(find . -name vspo_telemetry_report.log)\033[0m"
	echo -e "\033[0;32m##########################################\033[0m"
else
	echo -e "\033[0;31mCould not find file find vspo_telemetry_report.log. This is normal if these logs were collected by the vlc command.\033[0m"
fi
echo " "

# Combine and Count the number of S3 calls in s3-gateway*istio-proxy logs
echo -e "\033[0;32mCombining and counting the total number of S3 calls in istio s3-gateway istio-proxy logs into\033[0m all-s3-gateway-istio-proxy.txt"
for i in `find . -name "*s3-gateway*istio-proxy*" -print`; do cat $i >> all-s3-gateway-istio-proxy.txt; done
echo -e "\033[0;32mTotal number of S3 calls in s3-gateway istio-proxy logs:\033[0m `wc -l  all-s3-gateway-istio-proxy.txt | awk '{print $1}' | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"

# Count the number of downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mTotal number of downstream_remote_disconnect errors in S3 calls in s3-gateway istio-proxy logs:\033[0m `grep downstream_remote_disconnect all-s3-gateway-istio-proxy.txt | wc -l | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"

# Remove the downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mCopying S3 calls in s3-gateway istio-proxy logs without downstream_remote_disconnect errors into\033[0m all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt"
grep -v downstream_remote_disconnect all-s3-gateway-istio-proxy.txt > all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt

# Count the number of S3 calls ignoring downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mTotal number of S3 calls excluding downstream_remote_disconnect errors in s3-gateway istio-proxy logs:\033[0m `wc -l all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | awk '{print $1}' | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"

# Count the number of S3 status codes ignoring downstream_remote_disconnect errors
echo " "
echo -e "\033[0;32mCalculate the total size, min, max and avg time for all S3 status codes ignoring downstream_remote_disconnect errors\033[0m"
gawk -f - all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt <<'AWK'
{
    # Normalize line endings (in case of CRLF)
    sub(/\r$/, "", $0)

    # Extract and normalize method token
    method = $2
    gsub(/^"|"$/, "", method)  # remove leading/trailing double quotes

    # Status (often numeric/HTTP code)
    status = $5

    # Split full line by space
    n = split($0, f, " ")

    # Defensive: if we don't have enough fields, skip
    if (n < 12) next

    # Time (12th field)
    time = f[12]

    # Size selection: depends on method
    # Adjust if your log format differs
    if (method == "PUT") size = $10
    else size = $11

    # Convert to numbers
    time += 0
    size += 0

    # Build aggregation key
    key = method " " status

    # Filter only desired methods
    if (method != "DELETE" && method != "GET" && method != "HEAD" &&
        method != "POST"   && method != "PUT") {
        next
    }

    # Aggregate
    times[key] += time
    count[key]++
    sum[key] += size

    # Track min/max size if desired
    if (!(key in min) || size < min[key]) min[key] = size
    if (!(key in max) || size > max[key]) max[key] = size
}
END {
    # Sort by key ascending (gawk-only)
    PROCINFO["sorted_in"] = "@ind_str_asc"

    # Header
    printf "%-10s %-6s %12s %12s %12s %12s %12s\n",
           "METHOD", "STATUS", "COUNT", "TOTAL_SIZE", "MIN_SIZE", "MAX_SIZE", "AVG_TIME"

    # Rows
    for (k in count) {
        avg = times[k] / count[k]
        # split key into method and status for neat columns
        split(k, parts, " ")
        method = parts[1]
        status = parts[2]
        printf "%-10s %-6s %'12d %'12d %'12d %'12d %10.2f\n",
               method, status, count[k], sum[k], min[k], max[k], avg
    }
}
AWK

echo " "

# Checking Kubernetes nodes, namesspaces, pods, deployments, etc status
echo -e "\033[0;32mChecking kubernetes status\033[0m"
output=$(find . -name vspo_kubectl_get_nodes_A_o_wide.log -exec grep -v 'Ready' {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mNodes not in Ready state\033[0m"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_namespaces.log -exec grep -v 'Active' {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mNamespaces not in Active state\033[0m"
  echo "      NAME                                     STATUS   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_pods_A_o_wide.log -exec egrep -v 'Running|Completed' {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mPODs not in Completed or Running state\033[0m"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_cronjobs_A.log -exec grep -v False {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mCron Jobs not active\033[0m"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_deploy_A.log -exec cat {} \; | awk 'NR > 1 {split($3, ready, "/"); if (ready[1] != ready[2]) {print $0}}' | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mDeployments not all ready\033[0m"
  echo "      NAMESPACE                         NAME                                                             READY   UP-TO-DATE   AVAILABLE   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_statefulsets_A.log -exec cat {} \; | awk 'NR > 1 {split($3, ready, "/"); if (ready[1] != ready[2]) {print $0}}' | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mStatefulsets not all ready\033[0m"
  echo "      NAMESPACE                  NAME                                           READY   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_replicasets_A.log -exec cat {} \; | awk 'NR > 1 {desired=$3; current=$4; ready=$5; if (! (desired == current && current == ready)) {print $0}}' | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mReplicasets not all ready\033[0m"
  echo "      NAMESPACE                         NAME                                                                        DESIRED   CURRENT   READY   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_daemonsets_A.log -exec cat {} \; | awk 'NR > 1 {desired=$3; current=$4; ready=$5; if (! (desired == current && current == ready)) {print $0}}' | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mDaemonsets not all ready\033[0m"
  echo "      NAMESPACE                  NAME                                          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR              AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_pvc_A.log -exec grep -v 'Bound' {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mPVCs not Bound\033[0m"
  echo "      NAMESPACE           NAME                                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

output=$(find . -name vspo_kubectl_get_pv.log -exec grep -v 'Bound' {} \; | sed 's/^/      /')
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mPVs not Bound\033[0m"
  echo "      NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                              STORAGECLASS   REASON   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

# Check for WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application error
output=$(find . -name "s3-g*s3-g*.log*" -exec grep -B 1 "The difference between the request time and the server's time is too large" {} \; | grep "S3ServletAuthenticator" | awk '{print $2}' | sort)
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31Found occurrences of WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application error\033[0m"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

# Check for clock skew errors in yugabyte logs
echo "Checking for clock skew errors in yb-master and yb-tserver"
output=$(find . -name "*yb*server.log*" -exec grep "Too big clock skew is detected" {} \;)
echo $output > yb-time-skew.out
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31mToo big clock skew is detected in yb-master and yb-tserver\033[0m"
#  COUNT=$(printf "%s\n" "$output" | grep -c "Too big clock skew")
  matches=$(printf "%s\n" "$output" | sort -k1,1 -k2,2)
  # Count the number of matching lines
  count=$(printf "%s\n" "$matches" | wc -l)
  if [ "$count" -gt 10 ]; then
    echo -e "\033[0;31mThere are $count occurrences of this error, only displaying the first 2 and 2 most recent errors\033[0m"
    echo -e "\033[0;31mIssue the command \033[0mfind . -name \\\"*yb*server.log*\\\" -exec grep \\\"Too big clock skew is detected\\\" {} \; \033[0;31mto see all the errors\033[0m"
    echo -e "\033[0;31mHere are the first 2 occurrences of this error\033[0m"
    printf "%s\n" "$matches" | head -2
    echo -e "\033[0;31mHere are the 2 most recent occurrences of this error\033[0m"
    printf "%s\n" "$matches" | tail -2
   #printf "%s\n" "$output" | grep "Too big clock skew" | tail -2
  else
    printf "%s\n" "$matches" | grep "Too big clock skew"
  fi
#  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

# Record the script end time
END_TIME=$(date +%s)
echo " "
echo "Script completed at: $(date)"

# Calculate the total duration in seconds
DURATION=$((END_TIME - START_TIME))

# Calculate hours, minutes, and seconds from the total duration
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))
SECONDS=$((DURATION % 60))

# Display the elapsed time
echo "--------------------------------------------------"
echo "Script finished at $(date)"
echo "Total runtime: ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo "--------------------------------------------------"

unset LC_ALL
unset LC_NUMERIC
