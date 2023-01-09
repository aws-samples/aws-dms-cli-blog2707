### Read from Config file and set environment
if [[ -f "$CONFIGFILE" ]]; then
    PROFILE=`grep PROFILE $CONFIGFILE|awk '{print $2}'`
    REPLINSTANCEARN=`grep REPLINSTANCEARN $CONFIGFILE|awk '{print $2}'`
    CERTIFICATEARN=`grep CERTIFICATEARN $CONFIGFILE|awk '{print $2}'`
    REGION=`grep REGION $CONFIGFILE|awk '{print $2}'`
    FILE=`grep ENDPOINTFILE $CONFIGFILE|awk '{print $2}'`
    LINEBREAK=`grep LINEBREAK $CONFIGFILE|awk '{print $2}'`
    DBLISTFILE=`grep DBLISTFILE $CONFIGFILE|awk '{print $2}'`
	SOURCENAMEPREFIX=`grep SOURCENAMEPREFIX $CONFIGFILE|awk '{print $2}'`
	TARGETNAMEPREFIX=`grep TARGETNAMEPREFIX $CONFIGFILE|awk '{print $2}'`
    RUNNOW=`grep RUNNOW $CONFIGFILE|awk '{print $2}'`
    MIGRATIONTYPE=`grep MIGRATIONTYPE $CONFIGFILE|awk '{print $2}'`
    VERSION=`grep VERSION $CONFIGFILE|awk '{print $2}'`
    SETTINGFILE=`grep SETTINGFILE $CONFIGFILE|awk '{print $2}'`
    TABLEMAPFILE=`grep TABLEMAPFILE $CONFIGFILE|awk '{print $2}'`
    TAGFILE=`grep TAGFILE $CONFIGFILE|awk '{print $2}'`
else
    echo Config file $CONFIGFILE does not exist, quit ....
    exit 4
fi
