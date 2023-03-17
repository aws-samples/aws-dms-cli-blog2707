#!/usr/bin/env bash
#© 2022 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.
#This AWS Content is provided subject to the terms of the AWS Customer Agreement
#available at http://aws.amazon.com/agreement or other written agreement between
#Customer and either Amazon Web Services, Inc. or Amazon Web Services EMEA SARL or both.
### Require ENV and parameter
INPUTENV=$1
if [[ -n "$INPUTENV" ]]; then
        CONFIGFILE="$INPUTENV"
else
        CONFIGFILE=DMSPROFILE.ini

fi

### Read from Config file and set environment
if [[ -f "$CONFIGFILE" ]]; then
    . ./Load-Parm.sh "$CONFIGFILE"
else
    echo Config file "$CONFIGFILE" does not exist, quit ....
    exit 4
fi

#Take ID and password info as input 
read -rp 'SOURCE User Name: ' suser
read -rsp 'SOURCE Password: ' spassword
echo
read -rp 'TARGET User Name: ' tuser
read -rsp 'TARGET Password: ' tpassword
echo


SecretStringS={\"username\":\""$suser"\",\"password\":\""$spassword"\"}
SecretStringT={\"username\":\""$tuser"\",\"password\":\""$tpassword"\"}


SECRETARNS=$(aws secretsmanager --profile "$PROFILE" list-secrets --filters "Key=name,Values=DMSblog-Secret-SOURCE-${VERSION}" --region "$REGION"|grep arn|awk '{print $2}'|sed s/\"//g|sed s/,//)
DELETESSECRET=delete-DMS-secret.sh
true > "$DELETESSECRET"
chmod 700 "$DELETESSECRET"
#Create Source Secret if it does not exist
if [[ -n $SECRETARNS ]]; then
    echo Secret name DMSblog-Secret-SOURCE-"$VERSION" exists, bypass creation..
else 
    echo Create Secret name DMSblog-Secret-SOURCE-"$VERSION":
    aws secretsmanager --profile "$PROFILE" create-secret \
    --name DMSblog-Secret-SOURCE-"$VERSION" \
    --description "My DMS source database secret created with CLI" \
    --tag file://tag.json \
    --secret-string "${SecretStringS}" \
    --region "$REGION" \
    |tee secrets_source.out
    SECRETARNS=$(grep arn secrets_source.out|awk '{print $2}'|sed s/\"//g|sed s/,//)
    echo Generate delete script for Secret DMSblog-Secret-SOURCE-"$VERSION" in: "$DELETESSECRET"
    echo aws secretsmanager delete-secret --profile "$PROFILE" "$LINEBREAK" |tee -a  "$DELETESSECRET"
    echo "  " --secret-id  DMSblog-Secret-SOURCE-"$VERSION" --force-delete-without-recovery "$LINEBREAK"|tee -a  "$DELETESSECRET"
    echo "  " --region "$REGION"  |tee -a "$DELETESSECRET"
fi
echo SOURCEARN: "$SECRETARNS" > DMSSECRET.INI

#Create Target Secret if it does not exist
SECRETARNT=$(aws secretsmanager --profile "$PROFILE" list-secrets --filters "Key=name,Values=DMSblog-Secret-TARGET-$VERSION" --region "$REGION"|grep arn|awk '{print $2}'|sed s/\"//g|sed s/,//)
if [[ -n $SECRETARNT ]]; then
    echo Secret name DMSblog-Secret-TARGET-"$VERSION" exists, bypass creation..
else 
    echo Create Secret name DMSblog-Secret-TARGET-"$VERSION":
    aws secretsmanager --profile "$PROFILE" create-secret \
        --name DMSblog-Secret-TARGET-"$VERSION" \
        --description "My DMS target database secret created with CLI" \
        --tag file://tag.json \
        --secret-string "${SecretStringT}" \
        --region "$REGION" \
        |tee secrets_target.out
    SECRETARNT=$(grep arn secrets_target.out|awk '{print $2}'|sed s/\"//g|sed s/,//)
    echo Generate delete script for Secret DMSblog-Secret-TARGET-"$VERSION" in: "$DELETESSECRET"
    echo aws secretsmanager delete-secret --profile "$PROFILE" "$LINEBREAK" |tee -a  "$DELETESSECRET"
    echo "  " --secret-id  DMSblog-Secret-TARGET-"$VERSION" --force-delete-without-recovery "$LINEBREAK"|tee -a  "$DELETESSECRET"
    echo "  " --region "$REGION"  |tee -a "$DELETESSECRET"
fi
echo TARGETARN: "$SECRETARNT" >> DMSSECRET.INI
echo Secrets created successfully, DMSSECRET.INI generated. 
echo rm -f DMSSECRET.INI >> "$DELETESSECRET"
 
