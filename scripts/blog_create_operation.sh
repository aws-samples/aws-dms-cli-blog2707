#!/usr/bin/env bash
#© 2022 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.
#This AWS Content is provided subject to the terms of the AWS Customer Agreement
#available at http://aws.amazon.com/agreement or other written agreement between
#Customer and either Amazon Web Services, Inc. or Amazon Web Services EMEA SARL or both.
### Require ENV and parameter
INPUTENV=$1
if [[ -n "$INPUTENV" ]]; then
        CONFIGFILE=$INPUTENV
else
        CONFIGFILE=DMSPROFILE.ini

fi


### Read from Config file and set environment
if [[ -s "$CONFIGFILE" ]]; then
    echo Parameter file "$CONFIGFILE" exists. Load Parameters  ..
    . ./Load-Parm.sh "$CONFIGFILE"
else
    echo Parameter file "$CONFIGFILE" does not exist, quit ....
    exit 4
fi

DMSTASKID=dmstaskid.txt
##Check Databaae list file, it is used to creat endpoing and DMS tasks 
if test -f "$DMSTASKID"; then
        echo TaskID file dmstaskid.txt exists, continue..
else
        echo dmstaskid.txt file does not exist, please create task first
        exit 4
fi

DMSTDELETESCRIPT=delete-DMS-task.sh
true > "$DMSTDELETESCRIPT"
chmod 700 "$DMSTDELETESCRIPT"

STARTTASKSCRIPT=start-DMS-task.sh
true > "$STARTTASKSCRIPT"
chmod 700 "$STARTTASKSCRIPT"

STOPTASKSCRIPT=stop-DMS-task.sh
true > "$STOPTASKSCRIPT"
chmod 700 "$STOPTASKSCRIPT"

cat "$DMSTASKID"|while read -r TASKID
do
  TASKARN=$(aws --profile "$PROFILE" --region "$REGION" dms describe-replication-tasks --without-settings --filters="Name=replication-task-id,Values='${TASKID}'"|grep ReplicationTaskArn|awk '{print $2}'|sed s/\"//g|sed s/,//)
  echo aws dms start-replication-task --replication-task-arn "$TASKARN" --profile "$PROFILE" "$LINEBREAK" >> "$STARTTASKSCRIPT"
  echo   --start-replication-task-type start-replication --region "$REGION" >> "$STARTTASKSCRIPT"
  echo aws dms stop-replication-task --replication-task-arn "$TASKARN" --profile "$PROFILE" --region "$REGION">> "$STOPTASKSCRIPT"
  echo aws dms delete-replication-task --replication-task-arn "$TASKARN" --profile "$PROFILE" --region "$REGION">> "$DMSTDELETESCRIPT"
done

echo Script to Start DMS tasks "(first time only)": "$STARTTASKSCRIPT"
echo Script to Stop DMS tasks : "$STOPTASKSCRIPT"
echo Script to Delete DMS tasks : "$DMSTDELETESCRIPT"
echo Script to Delete DMS Endpoints : delete-DMS-endpoint.sh
echo Script to Delete Secrets : delete-DMS-secret.sh