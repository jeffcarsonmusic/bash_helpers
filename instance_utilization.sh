#!/bin/bash

# set start time -90 days
start=$(date -v -90d +"%Y-%m-%dT%H:%M:%S%z")
end=$(date +"%Y-%m-%dT%H:%M:%S%z")


echo "Getting list of EC2 instances"

# find active regions
regions=$(aws ec2 describe-regions --filters "Name=opt-in-status, Values=opt-in-not-required, opted-in" --query "Regions[].RegionName" --output text)

echo "Region,Instance_ID,Min,Max,Avg" >> instances.csv

# float rounding function:
round()
{
printf "%.2f" $1

};

# test regions for running instances
for y in $regions
do
    echo "Checking region $y"
    running_regions=$(aws ec2 describe-instances --region $y --query 'Reservations[].Instances[]' )

    if [ "$running_regions" = "[]" ];
        then 
        echo "Nothing Found"
        else
        echo "Found instances, collecting data";
        echo " "
        list=$(aws ec2 describe-instances --region $y --filters "Name=instance-state-name, Values=running" --query "Reservations[].Instances[].InstanceId" --output text)

        # if instances are found, get min, max, and avg CPU metrics
        echo $list
        for i in $list
        do
            ec2_name=$(aws ec2 describe-tags --region $y --filters "Name=resource-id,Values=$i" "Name=key,Values=Name" --output text | cut -f5)

            ec2_type=$(aws ec2 describe-instances --instance-ids=$i --region $y --query "Reservations[*].Instances[*].InstanceType" --output text)

            max=$(aws cloudwatch get-metric-statistics --region $y --metric-name CPUUtilization --start-time $start  --end-time $end --period 86400 --namespace AWS/EC2 --statistics Maximum --dimensions "Name=InstanceId,Value=$i" --query "Datapoints[].Maximum" --output text) 

            min=$(aws cloudwatch get-metric-statistics --region $y --metric-name CPUUtilization --start-time $start  --end-time $end --period 86400 --namespace AWS/EC2 --statistics Minimum --dimensions "Name=InstanceId,Value=$i" --query "Datapoints[].Minimum" --output text) 

            avg=$(aws cloudwatch get-metric-statistics --region $y --metric-name CPUUtilization --start-time $start  --end-time $end --period 86400 --namespace AWS/EC2 --statistics Average --dimensions "Name=InstanceId,Value=$i" --query "Datapoints[].Average" --output text) 
            
            # trim the values using round function to 2 decimals
            min_val=$(round "$min")
            max_val=$(round "$max")
            avg_val=$(round "$avg")

            # output to console
            #echo $y, $ec2_name, $ec2_type, $i, $min_val, $max_val, $avg_val

            echo $y, $ec2_name, $ec2_type, $i, $min_val, $max_val, $avg_val >> instances.csv
        done
    fi
done

echo "Instance utilization written to instances.csv file"




