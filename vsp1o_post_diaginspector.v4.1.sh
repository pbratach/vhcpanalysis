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
# Version 2:
#   Calculate the total size, min, max and avg time for all S3 status codes ignoring downstream_remote_disconnect errors
#
# Version 2.3:
#   If all-s3-gateway-istio-proxy.txt exists, rename it to all-s3-gateway-istio-proxy.txt.timestamp
#
# Version 3:
#   Added check for WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application" error
#
# Version 4:
#   Added display of the serial number and versions of VSP1O and Kubernetes
#   Updated check for Warning KI-1
#   Added display of issues if nodes, namespaces, pods, crojobs, deployments, statefulsets, replicasets, daemonsets, pvc, pv are not in good state
# Version 4.1:
#   Started formatting the wc output numbers with commas 
#   Display bucket information in vspo_telemetry_report.log
#
export LC_ALL="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
if [ -f all-s3-gateway-istio-proxy.txt ]; then
	echo "WARNING: File all-s3-gateway-istio-proxy.txt already exists, backing it up"
#####	mv all-s3-gateway-istio-proxy.txt all-s3-gateway-istio-proxy.txt.`stat -c %y all-s3-gateway-istio-proxy.txt | cut -d'.' -f1 | tr -d '-' | tr -d ' ' | tr -d ':'`
fi
echo -e "\033[0;32mVSP1O serial number \033[0m"
find . -name vspo_serial_number_get.log -exec grep value {} \; | awk '{print $2}' | sed 's/^/      /'
echo " "
echo -e "\033[0;32mVSP1O Kubernetes versions\033[0m"
find . -name vspo_kubectl_version_short.log -exec cat {} \; | sed 's/^/      /'
echo " "
echo -e "\033[0;32mVSP1O region(s) version \033[0m"
find . -name vspo_galaxy_info.log -exec grep -A1 name {} \; | sed 's/--//g'
echo " "
echo -e "\033[0;32mVSP1O bucket information \033[0m"
find . -name vspo_telemetry_report.log -exec cat {} \; 
echo -e "\033[0;32m##########################################\033[0m"

echo " "
echo -e "\033[0;32mCombining and counting the total number of S3 calls in istio s3-gateway istio-proxy logs into\033[0m all-s3-gateway-istio-proxy.txt"
#####for i in ` find . -name "*s3-gateway*istio-proxy*" -print`; do cat $i >> all-s3-gateway-istio-proxy.txt; done
# Count the number of S3 calls in istio s3 logs
echo -e "\033[0;32mTotal number of S3 calls in s3-gateway istio-proxy logs:\033[0m `wc -l  all-s3-gateway-istio-proxy.txt | awk '{print $1}' | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"
# Count the number of downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mTotal number of downstream_remote_disconnect errors in S3 calls in s3-gateway istio-proxy logs:\033[0m `grep downstream_remote_disconnect all-s3-gateway-istio-proxy.txt | wc -l | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"
# Remove the downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mCopying S3 calls in s3-gateway istio-proxy logs without downstream_remote_disconnect errors into\033[0m all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt"
#####grep -v downstream_remote_disconnect all-s3-gateway-istio-proxy.txt > all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt
# Count the number of S3 calls ignoring downstream_remote_disconnect errors in istio s3 logs
echo -e "\033[0;32mTotal number of S3 calls excluding downstream_remote_disconnect errors in s3-gateway istio-proxy logs:\033[0m `wc -l all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | awk '{print $1}' | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'`"

# Count the number of S3 status codes ignoring downstream_remote_disconnect errors
echo " "
echo -e "\033[0;32mCalculating total number and size of each S3 call status\033[0m"
echo -e "\033[0;32mBreakdown of S3 Calls, Status and Size\033[0m"
echo "Count  S3 Call  S3 Status  Total Size"
gawk '{
    method=$2;
    sub(/^"/, "", method);
    status=$5;
    if (method == "PUT") size = $10
    else size = $11
    key=method " " status;
    count[key]++;
    sum[key]+=size;
}
END {
    for (k in count) {
#        printf "%\'d, %\'d, %\'d\n", count[k], k, sum[k]
         printf "%'\''d, %s, %'\''d\n", count[k], k, sum[k];
    }
}' all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | egrep "DELETE|GET|HEAD|POST|PUT" | sort -k 2

# Count the number of S3 status codes ignoring downstream_remote_disconnect errors for a certain hour
echo " "
echo -e "\033[0;32mCalculate the total size, min, max and avg time for all S3 status codes ignoring downstream_remote_disconnect errors\033[0m"
gawk '
{
  # Extract method from quoted string
  sub(/^"/, "", method);
  op=$2

  # Split line into fields
  n = split($0, f, " ")

  # Time is always the 12th field from the start
  time = f[12]

  # Size logic based on method
  if (op == "\"PUT") size = f[10]
  else if (op == "\"GET" || op == "\"POST") size = f[11]
  else size = 0

  # Convert to numbers
  time += 0
  size += 0

  # Aggregate
  times[op] += time
  sizes[op] += size
  count[op]++
  if (min[op] == "" || time < min[op]) min[op] = time
  if (max[op] == "" || time > max[op]) max[op] = time
}
END {
  for (op in count) {
    avg = times[op] / count[op]
    printf "%s: count=%'\''d, total_size=%'\''d, min_time=%'\''d, max_time=%'\''d, avg_time=%.2f\n", op, count[op], sizes[op], min[op], max[op], avg
  }
}' all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | egrep "DELETE|GET|HEAD|POST|PUT" | sort -k 2

# Check for WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application" error
output=$(grep -B 1 "The difference between the request time and the server's time is too large" */s3-g*s3-g*.log* | grep "S3ServletAuthenticator" | awk '{print $2}' | sort)
if [ $(echo "$output" | wc -l) -gt 1 ]; then
  echo " "
  echo -e "\033[0;31Found occurrences of WARNING : KI-1 : Time sync issue between VSP Object nodes and S3 client/application error\033[0m"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

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
  echo -e "\033[0;31mPVCs not Bound\033[0m"
  echo "      NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                              STORAGECLASS   REASON   AGE"
  echo "$output"
  echo -e "\033[0;31m##########################################\033[0m"
fi

unset LC_ALL
unset LC_NUMERIC
