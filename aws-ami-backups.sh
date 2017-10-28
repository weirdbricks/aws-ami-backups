#!/bin/bash

# Author: Pablo Suarez
# Website: https://github.com/pavlops
# Usage: aws-ami-backup.sh <ec2-instance-id> <identifier> <retention days> <aws local profile>


#Initialize variables
currDate=$(date +%Y%m%d%H%M)
instanceId="$1"
instanceName="$2"
maxret=$3
profile=$4
name="*$instanceName auto*"

#Get AMIs from the instance
result=$(aws ec2 describe-images --filters "Name=name,Values=$name" --query 'Images[*].{CreationDate:CreationDate,ImageId:ImageId}' --output text --profile "$profile" | sort -r)

while read line; do
  let i++
  if [ "$i" -gt "$maxret" ]; then

    #Get snapshots from AMIs
    amiID=$(echo $line | awk -F ' ' '{print $2}')
    snapshots=$(aws ec2 describe-images --image-ids "$amiID" --query 'Images[0].BlockDeviceMappings[*].Ebs.{SnapshotId:SnapshotId}' --output text --profile "$profile")
    aws ec2 deregister-image --image-id "$amiID" --profile "$profile"
    echo "$amiID deleted."

    while read snapshotId; do
      aws ec2 delete-snapshot --snapshot-id "$snapshotId" --profile "$profile"
      echo "$snapshotId deleted."
    done <<< "$snapshots"

  fi
done <<< "$result"

#Create new AMI from the instance
aws ec2 create-image --instance-id "$instanceId" --name "$currDate $instanceName auto" --no-reboot --profile "$profile"
