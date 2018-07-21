#!/bin/bash

# Author: Pablo Suarez
# Website: https://github.com/pavlops
# Usage: aws-ami-backup.sh <ec2-instance-id> <identifier> <retention days> <aws local profile>
# Additions by Lampros Chaidas

#Initialize variables
currDate=$(date +%Y%m%d%H%M)
instanceId="$1"
instanceName="$2"
maxret=$3
profile=$4
name="*$instanceName auto*"

# run some sanity checks

# check if instanceId is empty
if [ -z "$instanceId" ]; then
        echo "Sorry, you must provide an instanceId."
        exit 1
fi

# check if instanceName is empty
if [ -z "$instanceName" ]; then
        echo "Sorry, you must provide an instanceName."
        exit 1
fi

# check if the aws profile is empty
if [ -z "$maxret" ]; then
        echo "Sorry, you must provide the max retention in days."
        exit 1
fi


# check if the aws profile is empty
if [ -z "$profile" ]; then
        echo "Sorry, you must provide an aws profile."
        exit 1
fi

# check if the aws binary is in the known paths
if ! hash aws 2>/dev/null
then
    echo "'aws' was not found in PATH"
fi

#Get AMIs from the instance name
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
aws ec2 create-image --instance-id "$instanceId" --name "$instanceName $currDate auto" --no-reboot --profile "$profile" --output=text | tee /tmp/ami_id.txt
AMI_ID=$(</tmp/ami_id.txt)
echo "`date` - Creating AMI with ID: \"$AMI_ID\" for instance \"$instanceId\" ($instanceName)"
state=`aws ec2 describe-images --image-ids $AMI_ID --query 'Images[0].State' --profile "$profile" --output=text`
seconds=0
# Wait until the AMI is complete
while [ "$state" == "pending" ]; do
  echo "State: $state - time in seconds: $seconds"
  sleep 10 
  state=`aws ec2 describe-images --image-ids $AMI_ID --query 'Images[0].State' --profile "$profile" --output=text`
  seconds=$((seconds + 10))
done
echo "`date` - Image complete!"
