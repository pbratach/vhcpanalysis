#!/bin/bash
#
# Combine all external-ingress-gateway log in istio s3 logs
for i in ` find . -name *external-ingress-gateway*istio-proxy* -print`; do echo $i; cat $i >> all-external-ingress-gateway.txt; done

echo -n "Count of s3 status records: "
< all-external-ingress-gateway.txt wc -l 

# Count the number of downstream_remote_disconnect errors in istio s3 logs
echo -n "Count of s3 status records with downstream_remote_disconnect errors in istio s3 logs: "
grep downstream_remote_disconnect all-external-ingress-gateway.txt | wc -l

# Remove the downstream_remote_disconnect errors in istio s3 logs
grep -v downstream_remote_disconnect all-external-ingress-gateway.txt > all-external-ingress-gateway-no-downstream_remote_disconnect.txt

# Count the number of S3 calls ignoring downstream_remote_disconnect errors in istio s3 logs
echo -n "Count of S3 status records ignoring downstream_remote_disconnect errors in istio s3 logs: "
< all-external-ingress-gateway-no-downstream_remote_disconnect.txt wc -l 

# Count the number of S3 status codes ignoring downstream_remote_disconnect errors
cat all-external-ingress-gateway-no-downstream_remote_disconnect.txt | tr -s " " | cut -d' ' -f 2,5 | sort | uniq -c | sed 's/"//' | egrep "DELETE|GET|HEAD|POST|PUT"
