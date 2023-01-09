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
if [[ -f "$CONFIGFILE" ]]; then
    echo Parameter file "$CONFIGFILE" exists. Load Parameters  ..
    . ./Load-Parm.sh "$CONFIGFILE"
else
    echo Parameter file "$CONFIGFILE" does not exist, quit ....
    exit 4
fi

##Check Databaae list file, it is used to creat endpoing and DMS tasks 
if test -f "$DBLISTFILE"; then
        echo Database list file "$DBLISTFILE" exists, continue..
else
        echo "$DBLISTFILE" file does not exist, please create it first
        exit 4
fi


###Get USERID and PASSWORD from Secrets
if test -f "DMSSECRET.INI"; then
        echo DMSSECRET.INI exists, bypass blog_create_secrets.sh and continue.. 
else
        echo DMSSECRET.INI file does not exist, run create_secrets.sh to create it ..
        ./blog_create_secrets.sh
fi

echo "Retrieve database credentials from Secrets Manager.."
SOUECEARN=$(grep SOURCEARN DMSSECRET.INI |awk '{print $2}')
TARGETARN=$(grep TARGETARN DMSSECRET.INI |awk '{print $2}')

SOURCEINFO=$(aws secretsmanager get-secret-value --profile "$PROFILE" \
    --secret-id "$SOUECEARN" \
    --version-stage AWSCURRENT \
    --region "$REGION" --output table | grep "SecretString")


SUSERID=$(echo "$SOURCEINFO"|awk '{print $3}'|sed s/{//|sed s/}//| cut -f 2 -d ":" | cut -f 1 -d "," | sed "s/\"//g")
SPASSWORD=$(echo "$SOURCEINFO"|awk '{print $3}'|sed s/{//|sed s/}//| cut -f 3 -d ":" | cut -f 1 -d "," | sed "s/\"//g")

TARGETINFO=$(aws secretsmanager get-secret-value --profile "$PROFILE" \
    --secret-id "$TARGETARN" \
    --version-stage AWSCURRENT \
    --region "$REGION" --output table | grep "SecretString")

TUSERID=$(echo "$TARGETINFO"|awk '{print $3}'|sed s/{//|sed s/}//| cut -f 2 -d ":" | cut -f 1 -d "," | sed "s/\"//g")
TPASSWORD=$(echo "$TARGETINFO"|awk '{print $3}'|sed s/{//|sed s/}//| cut -f 3 -d ":" | cut -f 1 -d "," | sed "s/\"//g")
#echo "$SUSERID"
#echo $SPASSWORD
#echo $TUSERID
#echo $TPASSWORD
echo "Database credentials retrieved successfully from Secrets Manager."

#Set script name for later execution
ENDPOINTSCRIPT=create-end-point.sh
true > "$ENDPOINTSCRIPT"
chmod 755 "$ENDPOINTSCRIPT"
TASKSCRTPTNAME=create-DMS-replication-Task.sh
true > "$TASKSCRTPTNAME"
chmod 700 "$TASKSCRTPTNAME"
VTASKSCRTPTNAME=create-DMS-validation-full-load-Task.sh
true > "$VTASKSCRTPTNAME"
chmod 700 "$VTASKSCRTPTNAME"
VTASKSCRTPTNAME1=create-DMS-validation-cdc-Task.sh
true > "$VTASKSCRTPTNAME1"
chmod 700 "$VTASKSCRTPTNAME1"
EPCONSCRTPTNAME=create-DMS-ENDPOINT-Test-Connection.sh
true > "$EPCONSCRTPTNAME"
chmod 700 "$EPCONSCRTPTNAME"




#Get rid of empty line
sed -i '' '/^$/d' "$DBLISTFILE"
echo Start reading database information from "$DBLISTFILE" and creating Endpoints...
exit 0
grep -v RecordFormat "$DBLISTFILE"|while read -r EPTYPE DBENGINE DBNAME PORT HOSTNAME
do
    #custom setting for each engine 
    #EXTRA option can be set 
    #EXTRA= "--extra-connection-attributes multiSubnetFailover=Yes"
    EXTRA=""
    case "$DBENGINE" in
    db2)
        SETTINGFILE="tasksetting_db2.json"
        DBSETTING="$DBENGINE"-settings 
        EXTRA="--certificate-arn $CERTIFICATEARN"
        SSLMODE="--ssl-mode verify-ca"
        ;;
    oracle)
        DBSETTING="$DBENGINE"-settings
        EXTRA="--certificate-arn $CERTIFICATEARN"
        SSLMODE="--ssl-mode verify-ca"
        ;;
    aurora-postgresql)
        DBSETTING=postgre-sql-settings
        SSLMODE="--ssl-mode require"
        ;;
    sqlserver)
        DBSETTING=microsoft-sql-server-settings
        SSLMODE="--ssl-mode require"
        ;;
    *)
        DBSETTING="$DBENGINE"-settings
        SSLMODE=""
        ;;
    esac

    #Replace _ with - so that it can be used in identifier
	DBNAME1=$(echo "$DBNAME"|sed 's/_/-/')
    
    if [ "$EPTYPE" == "source" ] ; then
        SDBNAME1="$DBNAME1"
        
        #Create Source Endpoint
        echo 
        echo Generating Source Endpoint "$SOURCENAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$SDBNAME1" Script: "$ENDPOINTSCRIPT"
        true > "$ENDPOINTSCRIPT"
        echo aws dms create-endpoint --profile "$PROFILE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --endpoint-identifier "$SOURCENAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$SDBNAME1" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --endpoint-type "$EPTYPE" $SSLMODE $EXTRA"$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --engine-name "$DBENGINE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --database-name "$DBNAME" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --username "$SUSERID" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --password "$SPASSWORD" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --server-name "$HOSTNAME" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --port "$PORT" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --tags file://"$TAGFILE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --region "$REGION" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo Running Source Endpoint creation script: "$ENDPOINTSCRIPT"
        ./"$ENDPOINTSCRIPT" |tee create_endpoint_"$SOURCENAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$SDBNAME1".out

        #Get Source Endpoint ARN
        SOURCEENDPOINTARN=$(grep EndpointArn create_endpoint_"$SOURCENAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$SDBNAME1".out|awk '{print $2}'|sed s/\"//g|sed s/,//)
        
        #Generate Test connection script for Source Endpoint
        echo
        echo Generate Test connection script for Source Endpoint "$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$SDBNAME1": "$EPCONSCRTPTNAME"
        echo aws dms test-connection --profile "$PROFILE" "$LINEBREAK" |tee -a "$EPCONSCRTPTNAME"
        echo "  " --replication-instance-arn "$REPLINSTANCEARN" "$LINEBREAK" |tee -a "$EPCONSCRTPTNAME"
        echo "  " --endpoint-arn "$SOURCEENDPOINTARN" "$LINEBREAK" |tee -a "$EPCONSCRTPTNAME"
        echo "  " --region "$REGION" |tee -a "$EPCONSCRTPTNAME"
        echo "  " |tee -a "$EPCONSCRTPTNAME"
    
    elif [ "$EPTYPE" == "target" ] ; then
        TDBNAME1="$DBNAME1"

        #Create Target Endpoint
        echo
        echo Generating Target endpoint "$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$TDBNAME1": "$ENDPOINTSCRIPT"
        true > "$ENDPOINTSCRIPT"
        echo aws dms create-endpoint --profile "$PROFILE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --endpoint-identifier  "$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$TDBNAME1" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --endpoint-type "$EPTYPE" $SSLMODE $EXTRA "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --engine-name "$DBENGINE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --database-name "$DBNAME" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --username "$TUSERID" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --password "$TPASSWORD" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --server-name "$HOSTNAME" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --port "$PORT" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --tags file://"$TAGFILE" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo  --region "$REGION" "$LINEBREAK" |tee -a "$ENDPOINTSCRIPT"
        echo Running Target Endpoint creation script: "$ENDPOINTSCRIPT"
        ./"$ENDPOINTSCRIPT" |tee create_endpoint_"$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$TDBNAME1".out

        #Get Endpoing ARN
        TARGETENDPOINTARN=$(grep EndpointArn create_endpoint_"$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$TDBNAME1".out|awk '{print $2}'|sed s/\"//g|sed s/,//)

        #Generate Test connection script for Target Endpoint
        echo
        echo Generating Test Connection task script for Target endpoint "$TARGETNAMEPREFIX"-"$EPTYPE"-"$DBENGINE"-"$TDBNAME1": "$EPCONSCRTPTNAME"
        echo aws dms test-connection --profile "$PROFILE" "$LINEBREAK" |tee -a  "$EPCONSCRTPTNAME"
        echo "  " --replication-instance-arn "$REPLINSTANCEARN" "$LINEBREAK" |tee -a  "$EPCONSCRTPTNAME"
        echo "  " --endpoint-arn "$TARGETENDPOINTARN" "$LINEBREAK" |tee -a  "$EPCONSCRTPTNAME"
        echo "  " --region "$REGION" |tee -a  "$EPCONSCRTPTNAME"
        echo "  " |tee -a  "$EPCONSCRTPTNAME"

        ## Generate DMS replication task script
        echo 
        echo Generating DMS Replication task script for "$SDBNAME1"-"$TDBNAME1"-"$DBENGINE"-"$MIGRATIONTYPE" to script: "$TASKSCRTPTNAME"
        echo aws dms create-replication-task --profile "$PROFILE" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --replication-task-identifier "$SDBNAME1"-"$TDBNAME1"-"$DBENGINE"-$MIGRATIONTYPE "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --source-endpoint-arn "$SOURCEENDPOINTARN" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --target-endpoint-arn "$TARGETENDPOINTARN" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --replication-instance-arn "$REPLINSTANCEARN" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --migration-type "$MIGRATIONTYPE" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --tags file://"$TAGFILE" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --table-mappings file://"$TABLEMAPFILE"  "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --replication-task-settings file://"$SETTINGFILE" "$LINEBREAK" |tee -a  "$TASKSCRTPTNAME"
        echo "  " --region "$REGION" |tee -a  "$TASKSCRTPTNAME"
        echo "  " |tee -a  "$TASKSCRTPTNAME"

        #Generate Full-load Validation task script 
        echo 
        echo Generating Full-load Validation task script for Validation-full-load-"$SDBNAME1"-"$TDBNAME1"-"$DBENGINE": "$VTASKSCRTPTNAME"
        echo aws dms create-replication-task --profile "$PROFILE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --replication-task-identifier Validation-full-load-"$SDBNAME1"-"$TDBNAME1"-"$DBENGINE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --source-endpoint-arn "$SOURCEENDPOINTARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --target-endpoint-arn "$TARGETENDPOINTARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --replication-instance-arn "$REPLINSTANCEARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --migration-type full-load "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --tags file://"$TAGFILE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --table-mappings file://"$TABLEMAPFILE"  "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --replication-task-settings file://tasksetting_validation.json "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " --region "$REGION" |tee -a  "$VTASKSCRTPTNAME"
        echo "  " |tee -a  "$VTASKSCRTPTNAME"

        #Generate cdc Validation task script 
        echo 
        echo Generating CDC Validation task script for Validation-cdc-"$SDBNAME1"-"$TDBNAME1"-"$DBENGINE": "$VTASKSCRTPTNAME1"       
        echo aws dms create-replication-task --profile "$PROFILE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --replication-task-identifier Validation-cdc-"$SDBNAME1"-"$TDBNAME1"-"$DBENGINE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --source-endpoint-arn "$SOURCEENDPOINTARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --target-endpoint-arn "$TARGETENDPOINTARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --replication-instance-arn "$REPLINSTANCEARN" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --migration-type cdc "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --tags file://"$TAGFILE" "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --table-mappings file://"$TABLEMAPFILE"  "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --replication-task-settings file://tasksetting_validation.json "$LINEBREAK" |tee -a  "$VTASKSCRTPTNAME1"
        echo "  " --region "$REGION"|tee -a  "$VTASKSCRTPTNAME1"
        echo "  " |tee -a  "$VTASKSCRTPTNAME1"
    else 
        echo Endpoint Type is neither source nor target, quiting....
        echo 4
    fi
done

#Add Check Endpoint connection testing result to Test Connection script
echo "echo sleep 60s to wait for test connection result" >> "$EPCONSCRTPTNAME"
echo sleep 60 >> "$EPCONSCRTPTNAME"
echo "echo Connection test status:" >> "$EPCONSCRTPTNAME"
echo aws dms describe-connections --profile "$PROFILE" "$LINEBREAK" >> "$EPCONSCRTPTNAME"
echo "  " --region  "$REGION"  \|egrep \'Status\|EndpointIdentifier\' >> "$EPCONSCRTPTNAME"



if [ $RUNNOW = "YES" ] ; then
    echo Running Test Connection script: "$EPCONSCRTPTNAME"
    ./"$EPCONSCRTPTNAME" |tee "$EPCONSCRTPTNAME".out
    echo Running DMS Replication Task Script: "$TASKSCRTPTNAME"
    ./"$TASKSCRTPTNAME" |tee "$TASKSCRTPTNAME".out
    echo Running DMS Full Load Validation Task Script: "$VTASKSCRTPTNAME"
    ./"$VTASKSCRTPTNAME" |tee "$VTASKSCRTPTNAME".out
    echo Running DMS CDC Validation Task Script: "$VTASKSCRTPTNAME1"
    ./"$VTASKSCRTPTNAME1" |tee "$VTASKSCRTPTNAME1".out
else
    echo These scripts can run manually: 
    echo Script for Endpoints Test Connection is: "$EPCONSCRTPTNAME"
    echo Script for DMS Replication Task is: "$TASKSCRTPTNAME"
    echo Script for DMS Validation\(Full Load\) Task is: "$VTASKSCRTPTNAME"
    echo Script for DMS Validation\(CDC\) Task is: "$VTASKSCRTPTNAME1" 
fi


 