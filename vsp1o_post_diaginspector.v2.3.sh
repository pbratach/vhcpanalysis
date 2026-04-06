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
# Version 3:
#   If all-s3-gateway-istio-proxy.txt exists, rename it to all-s3-gateway-istio-proxy.txt.timestamp
#
if [ -f all-s3-gateway-istio-proxy.txt ]; then
	echo "WARNING: File all-s3-gateway-istio-proxy.txt already exists, backing it up"
	mv all-s3-gateway-istio-proxy.txt all-s3-gateway-istio-proxy.txt.`stat -c %y all-s3-gateway-istio-proxy.txt | cut -d'.' -f1 | tr -d '-' | tr -d ' ' | tr -d ':'`
fi
echo "Counting the total number of S3 calls in istio s3 logs"
for i in ` find . -name "*s3-gateway*istio-proxy*" -print`; do cat $i >> all-s3-gateway-istio-proxy.txt; done
# Count the number of S3 calls in istio s3 logs
echo "Total number of S3 calls in s3-gateway istio-proxy logs: `wc -l  all-s3-gateway-istio-proxy.txt | awk '{print $1}'`"
# Count the number of downstream_remote_disconnect errors in istio s3 logs
echo "Total number of downstream_remote_disconnect errors in S3 calls in s3-gateway istio-proxy logs: `grep downstream_remote_disconnect all-s3-gateway-istio-proxy.txt | wc -l`"
# Remove the downstream_remote_disconnect errors in istio s3 logs
grep -v downstream_remote_disconnect all-s3-gateway-istio-proxy.txt > all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt
# Count the number of S3 calls ignoring downstream_remote_disconnect errors in istio s3 logs
echo "Total number of S3 calls excluding downstream_remote_disconnect errors in s3-gateway istio-proxy logs: `wc -l all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | awk '{print $1}'`"
# Count the number of S3 status codes ignoring downstream_remote_disconnect errors
echo " "
echo "Breakdown of S3 Calls, Status and Size"
echo "Count  S3 Call  S3 Status  Total Size"
awk '{
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
        print count[k], k, sum[k];
    }
}' all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | egrep "DELETE|GET|HEAD|POST|PUT" | sort -k 2
# Count the number of S3 status codes ignoring downstream_remote_disconnect errors for a certain hour
echo " "
echo "Calculate the total size, min, max and avg time for all S3 status codes ignoring downstream_remote_disconnect errors"
#cat all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | tr -s " " | awk -F' ' '$1 ~ /2025-06-20T00/ {print "2025-06-20T00",$2,$5}' | sort | uniq -c | sed 's/"//' | egrep "DELETE|GET|HEAD|POST|PUT"
awk '
{
  # Extract method from quoted string
  sub(/^"/, "", method);
  op=$2

  # Split line into fields
  n = split($0, f, " ")

  # Time is always the 12th field from the start
  time = f[12]

  # Size logic based on method
  if (op == "PUT") size = f[10]
  else if (op == "GET" || op == "POST") size = f[11]
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
    printf "%s: count=%d, total_size=%d, min_time=%d, max_time=%d, avg_time=%.2f\n", op, count[op], sizes[op], min[op], max[op], avg
  }
}' all-s3-gateway-istio-proxy.txt-no-downstream_remote_disconnect.txt | egrep "DELETE|GET|HEAD|POST|PUT" | sort -k 2
