#find ./$1 -name "server.log*" -type f | xargs -I logs grep -H  -i "deadline_" logs  |awk -F=/ '{print $2}'  |  sed -e 's/]//g' | sort | uniq -c | tee $1.deadline-for-sustaining.txt
find ./140 -name server.log* -print | grep clientaccess | xargs -I logs grep -H  -i "deadline.exceeded" logs  |awk -F=/ '{print $2}'  |  sed -e 's/]//g' | sort | uniq -c | tee $1.s3.deadline-for-sustaining.txt
