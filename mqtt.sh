#!/bin/sh
#set -x
# Initialize our own variables:
if [ ! -f $(dirname $0)/mqtt.cfg ] ; then
	echo "$(dirname $0)/mqtt.cfg not found"
	echo "set defaults"
	# CCU IP addr
	HOMEMATIC='127.0.0.1'
	# MQTT server IP addr
	MQHOST='127.0.0.1'
	# MQTT server port
	MQPORT=1883
	# MQTT options
	MQOPTION=''
else
. $(dirname $0)/mqtt.cfg
fi
DEBUG=0
SENSOR=''
SENSOR2=''
SENSOR3=''
CHANNEL=''
TOPIC=''
ONLINE=''
ADDON_DIR=/usr/local/addons/mosquitto
SUB="$ADDON_DIR/bin/mosquitto_sub"
PUB="$ADDON_DIR/bin/mosquitto_pub"
CURL_timout='-m 5'
StatusNET=''
StatusSNS=''
StatusSTS=''
RELNR=''


# extend PATH
if [ -d /usr/local/addons/redmatic/bin  ] ; then
        test=$(echo $PATH | grep '/usr/local/addons/redmatic/bin')
        if [ $? -ne 0 ] ; then
                PATH=/usr/local/addons/redmatic/bin:$PATH
        fi
fi
if [ -d /usr/bin ] ; then
        test=$(echo $PATH | grep '/usr/bin')
        if [ $? -ne 0 ] ; then
                PATH=$PATH:/usr/bin
        fi
fi
if [ -d /usr/local/bin ] ; then
        test=$(echo $PATH | grep '/usr/local/bin')
        if [ $? -ne 0 ] ; then
                PATH=$PATH:/usr/local/bin
        fi
fi
if [ -d /usr/local/addons/cuxd ] ; then
        test=$(echo $PATH | grep '/usr/local/addons/cuxd')
        if [ $? -ne 0 ] ; then
                PATH=$PATH:/usr/local/addons/cuxd
        fi
fi
if [ -d /usr/local/addons/redmatic/lib ] ; then
        test=$(echo $LD_LIBRARY_PATH | grep '/usr/local/addons/redmatic/lib')
        if [ $? -ne 0 ] ; then
                LD_LIBRARY_PATH=/usr/local/addons/redmatic/lib:$LD_LIBRARY_PATH
        fi
fi

# check if binaries exists
if [ ! -x $SUB ] ; then
	echo "$SUB not found"
	echo 'please install the addon mosquitto https://github.com/hobbyquaker/ccu-addon-mosquitto/releases'
fi
if [ ! -x $PUB ] ; then
        echo "$PUB not found"
        echo 'please install the addon mosquitto https://github.com/hobbyquaker/ccu-addon-mosquitto/releases'
fi

# find commands
GETOPT=$(which getopt)
if [ $? -ne 0 ] ; then
        echo 'ERROR: getopt not found'
	exit 1
fi

CURL=$(which curl)
if [ $? -ne 0 ] ; then
        echo 'ERROR: curl not found'
	exit 1
fi
CURL_timout='-m 5'
JQ=$(which jq)
if [ $? -ne 0 ] ; then
        echo 'ERROR: jq not found'
	echo 'You need raspberrymatic https://raspberrymatic.de/'
	exit 1
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# functions

usage() {
        echo 'usage:'
	echo -e "\t $(basename $0) -c <CUX2801xxx:x> -t <TOPIC> [-o <value>] [-r <ccuname>] [-s <sensor1,sensor2,...>] [-n <number>] [-d]"
        echo -e "\t $(basename $0) --channel <CUX2801xxx:x> --topic <TOPIC> [--value <value>] [--realname <ccuname>] [--sensor <sensor1,sensor2,...>] [--relaynumber <number>] [--debug]"
	echo
	echo "OPTIONS"
	echo -e "\t-c | --channel    \tCUxD channel name"
	echo -e "\t-t | --topic      \tTasmota device topic name"
	echo -e "\t-o | --value      \tPower cmnd [0 - off, 1 - on, 2 - toggle]"
	echo -e "\t-r | --realname   \tActual name for the variable definition."
	echo -e "\t-s | --sensor     \tQuery of sensor data,"
        echo -e "\t                  \tYou can pass a list of sensors separated by commas."
	echo -e "\t                  \t(ENERGY, DS18B20, AM2301, BMP280, BME280, TSL2561 and BH1750)"
	echo -e "\t-n | --relaynumber\tFor devices with mor than one relay you can give the relay number."
	echo -e "\t-d | --debug      \tDebug information and names for CCU systemvariables"
	echo
	echo "PREREQUISITE"
	echo -e "\tRaspberrymatic and mosquitto addon"
	echo
	echo "EXAMPLE"
	echo -e "\t $(basename $0) -c CUX2801006:1 -t tasmota-device -o 1"
	echo -e "\t\tThis command switches on the relay of the tasmota-device."
	echo
	echo -e "\t $(basename $0) -c CUX2801006:1 -t tasmota-device -o 0"
	echo -e "\t\tThis command switches off the relay of the tasmota-device."
	echo
	echo -e "\t $(basename $0) -c CUX2801006:14 -t display1 -r display1 -s BME280,BH1750"
	echo -e "\t\tThis command reads the status of the device with the topic display1 and the sensors BME280 and BH1750."
        echo -e "\t\tSince the real name was changed to display1, the following variables are set in the CCU."
	echo
	echo -e "\t\tdisplay1-status, display1-ipaddr, display1-RSSI, display1-temperature, display1-pressure,"
	echo -e "\t\tdisplay1-seapressure, display1-humidity, display1-illuminance"
	echo
	debugmsg
        exit 0
}

get_sensors(){
	case $1 in
	"ENERGY")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS' | ${JQ} '.ENERGY' )
		TOTAL=$(echo $STATE | ${JQ} '.Total' )
		TOTAL_EH='kWh'
		TOTAL_VAR='total'
		YESTERDAY=$(echo $STATE | ${JQ} '.Yesterday' )
		YESTERDAY_EH='kWh'
		YESTERDAY_VAR='yesterday'
		TODAY=$(echo $STATE | ${JQ} '.Today' )
		TODAY_EH='kWh'
		TODAY_VAR='today'
		POWER=$(echo $STATE | ${JQ} '.Power' )
		POWER_EH='W'
		POWER_VAR='power'
		FACTOR=$(echo $STATE | ${JQ} '.Factor' )
		FACTOR_EH=''
		FACTOR_VAR='factor'
		VOLTAGE=$(echo $STATE | ${JQ} '.Voltage' )
		VOLTAGE_VAR='voltage'
		AMPERE=$(echo $STATE | ${JQ} '.Current' )
		AMPERE_VAR='ampere'


		echo -e "\t[${REALNAME}-${TOTAL_VAR}]:     $TOTAL $TOTAL_EH"
                echo -e "\t[${REALNAME}-${YESTERDAY_VAR}]: $YESTERDAY $YESTERDAY_EH"
                echo -e "\t[${REALNAME}-${TODAY_VAR}]:     $TODAY $TODAY_EH"
                echo -e "\t[${REALNAME}-${POWER_VAR}]:     $POWER $POWER_EH"
                echo -e "\t[${REALNAME}-${FACTOR_VAR}]:    $FACTOR $FACTOR_EH"
                echo -e "\t[${REALNAME}-${VOLTAGE_VAR}]:   $VOLTAGE V"
                echo -e "\t[${REALNAME}-${AMPERE_VAR}]:    $AMPERE A"
                set_CCU_SysVar $TOTAL $REALNAME-${TOTAL_VAR}
                set_CCU_SysVar $YESTERDAY $REALNAME-${YESTERDAY_VAR}
                set_CCU_SysVar $TODAY $REALNAME-${TODAY_VAR}
                set_CCU_SysVar $POWER $REALNAME-${POWER_VAR}
                set_CCU_SysVar $FACTOR $REALNAME-${FACTOR_VAR}
                set_CCU_SysVar $VOLTAGE $REALNAME-voltage
                set_CCU_SysVar $AMPERE $REALNAME-ampere

		;;
	"DS18B20")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.DS18B20.Temperature'; )
		echo -e "\t[$REALNAME-temperature]:        $STATE C"
		set_CCU_SysVar $STATE $REALNAME-temperature
		;;
	"AM2301")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.AM2301.Temperature'; )
		echo -e "\t[$REALNAME-temperature]:        $STATE C"
		set_CCU_SysVar $STATE $REALNAME-temperature
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.AM2301.Humidity'; )
		echo -e "\t[$REALNAME-humidity]:           $STATE %"
		set_CCU_SysVar $STATE $REALNAME-humidity
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.AM2301.DewPoint'; )
		echo -e "\t[$REALNAME-dewpoint]:           $STATE C"
		set_CCU_SysVar $STATE $REALNAME-dewpoint
		;;
	"BMP280")
	        STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BMP280.Temperature'; )
                echo -e "\t[$REALNAME-temperature]:        $STATE C"
		set_CCU_SysVar $STATE $REALNAME-temperature
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BMP280.Pressure'; )
		echo -e "\t[$REALNAME-pressure]:           $STATE hPa"
		set_CCU_SysVar $STATE $REALNAME-pressure
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BMP280.SeaPressure'; )
		echo -e "\t[$REALNAME-seapressure]:        $STATE hPa"
		set_CCU_SysVar $STATE $REALNAME-seapressure
		;;
	"BME280")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BME280.Temperature'; )
		echo -e "\t[$REALNAME-temperature]:        $STATE C"
		set_CCU_SysVar $STATE $REALNAME-temperature
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BME280.Pressure'; )
		echo -e "\t[$REALNAME-pressure]:           $STATE hPa"
		set_CCU_SysVar $STATE $REALNAME-pressure
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BME280.SeaPressure'; )
		echo -e "\t[$REALNAME-seapressure]:        $STATE hPa"
		set_CCU_SysVar $STATE $REALNAME-seapressure
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BME280.Humidity'; )
		echo -e "\t[$REALNAME-humidity]:           $STATE %"
		set_CCU_SysVar $STATE $REALNAME-humidity
		;;
	"BH1750")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.BH1750.Illuminance'; )
		echo -e "\t[$REALNAME-illuminance]:        $STATE lx"
		set_CCU_SysVar $STATE $REALNAME-illuminance
		;;
	"TSL2561")
		STATE=$( echo $StatusSNS | ${JQ} '.StatusSNS.TSL2561.Illuminance'; )
		echo -e "\t[$REALNAME-illuminance]:        $STATE lx"
		set_CCU_SysVar $STATE $REALNAME-illuminance
		;;
	*)
		echo "Warning: $1 not defined"
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.Pressure"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-pressure]:           $STATE hPa"
			set_CCU_SysVar $STATE $REALNAME-$1-pressure
			STATE=
		fi
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.SeaPressure"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-seapressure]:        $STATE hPa"
			set_CCU_SysVar $STATE $REALNAME-$1-seapressure
			STATE=
		fi
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.Temperature"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-temperature]:        $STATE C"
			set_CCU_SysVar $STATE $REALNAME-$1-temperature
			STATE=
		fi
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.Humidity"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-humidity]:           $STATE %"
			set_CCU_SysVar $STATE $REALNAME-$1-humidity
			STATE=
		fi
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.DewPoint"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-dewpoint]:           $STATE C"
			set_CCU_SysVar $STATE $REALNAME-$1-dewpoint
			STATE=
		fi
		STATE=$( echo $StatusSNS | ${JQ} ".StatusSNS.$1.Illuminance"; )
		if [ $STATE != 'null' ] ; then
			echo -e "\t[$REALNAME-$1-illuminance]:        $STATE lx"
			set_CCU_SysVar $STATE $REALNAME-$1-illuminance
			STATE=
		fi
		# not defined
		;;
	esac
}

get_powerstate(){
	POWERSUB=$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $SUB -h $MQHOST -p $MQPORT $MQOPTION -W 15 -C 1 -R -v -t stat/$TOPIC/POWER$RELNR )
	POWERSTATE=$(echo $POWERSUB | awk '{ print $2 }')
	case $POWERSTATE in
        "ON")
		STATUS=1
		;;
	"OFF")
		STATUS=0
		;;
	*)
		STATUS=2
		;;
	esac
	
	set_CUxD_state $STATUS $CHANNEL
}

force_powerstate(){
	$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $PUB -h $MQHOST -p $MQPORT $MQOPTION -t cmnd/$TOPIC/backlog -m power$RELNR )
}

set_powercmnd(){
	$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $PUB -h $MQHOST -p $MQPORT $MQOPTION -t cmnd/$TOPIC/power$RELNR -m $CMND )
}

set_CCU_SysVar(){
        Debugmsg1=$Debugmsg1"set_CCU_SysVar: \n\t\tValue: $1\n\t\tCCU-System-Variable: $2\n"
        if [ "x$1" != "x" ]; then
                Debugmsg1=$Debugmsg1"\t\thttp://$HOMEMATIC:8181/Test.exe?Status=dom.GetObject%28%27$2%27%29.State%28%22$1%22%29 \n"
                TEST=$(LD_LIBRARY_PATH=/usr/lib && ${CURL} -s $CURL_timout "http://$HOMEMATIC:8181/Test.exe?Status=dom.GetObject%28%27$2%27%29.State%28%22$1%22%29")
        else
                Debugmsg1=$Debugmsg1"\t\t$IPADDR -> set_CCU_SysVar: $2 - Fehler, keine Status.\n"
                logger -i -t $0 -p 3 "$IPADDR -> set_CCU_SysVar: $2 - Fehler, keine Status." >> /dev/null 2>&1
        fi
}

set_CUxD_state(){
        Debugmsg1=$Debugmsg1"set_CUxD_state: \n\t\tValue: $1\n\t\tCUX-CHANNEL: $2\n"
        if [ "x$1" != "x" ]; then
                Debugmsg1=$Debugmsg1"\t\thttp://$HOMEMATIC:8181/Test.exe?Status=dom.GetObject%28%27CUxD.$2.SET_STATE%27%29.State%28%22$1%22%29 \n"
                TEST=$(LD_LIBRARY_PATH=/usr/lib && ${CURL} -s $CURL_timout "http://$HOMEMATIC:8181/Test.exe?Status=dom.GetObject%28%27CUxD.$2.SET_STATE%27%29.State%28%22$1%22%29")
        else
                Debugmsg1=$Debugmsg1"\t\t$IPADDR -> set_CUxD_state: $2 - Fehler, keine Status.\n"
                logger -i -t $0 -p 3 "$IPADDR -> set_CUxD_state: $2 - Fehler, keine Status." >> /dev/null 2>&1
        fi
}

debugmsg(){
	if [ $DEBUG -eq 1 ] ; then
		Debugmsg1=$Debugmsg1"\n-----------------------------------------------------------------------------------------------------\n\n"
	        Debugmsg1=$Debugmsg1"Channel:     $CHANNEL\n"
	        Debugmsg1=$Debugmsg1"Topic:       $TOPIC\n"
	        Debugmsg1=$Debugmsg1"Value:       $CMND\n"
		Debugmsg1=$Debugmsg1"Time:        $Time\n"
		Debugmsg1=$Debugmsg1"Realname:    $REALNAME\n"
		Debugmsg1=$Debugmsg1"RelayNumber: $RELNR\n"
		Debugmsg1=$Debugmsg1"PowerSub:    $POWERSUB\n"
		Debugmsg1=$Debugmsg1"Power:       $STATUS\n"
		Debugmsg1=$Debugmsg1"StatusNET:\n$StatusNET\n"
		Debugmsg1=$Debugmsg1"StatusSNS:\n$StatusSNS\n"
		Debugmsg1=$Debugmsg1"StatusSTS:\n$StatusSTS\n"
	        echo -e "\n\n"
	        echo -e "-----------------------------------------------------------------------------------------------------"
	        echo -e "                                       Debug Ausgaben"
	        echo -e "-----------------------------------------------------------------------------------------------------"
	        echo -e $Debugmsg1
	fi
}

get_ccu_var_info(){
	echo -e "\n\n-----------------------------------------------------------------------------------------------------"
	echo -e "                                       CCU Systemvariablen"
	echo -e "-----------------------------------------------------------------------------------------------------"
	echo
	echo -e "\t[$REALNAME-status]:             $AVAILABLE"
        echo -e "\t[$REALNAME-ipaddr]:             ${IPAddress}"
	echo -e "\t[$REALNAME-RSSI]:               ${Signal}"
	echo -e "\t[$REALNAME-Time]:               ${Time}"
}

OPT=`${GETOPT} -o h:c:t:o:s:n:r:d --long help,channel:,topic:,value:,sensor:,relaynumber:,realname:,debug -- "$@"`
eval set -- "$OPT"
while true; do
    case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
    -c|--channel)  
	CHANNEL=$2
	shift 2
        ;;	
    -t|--topic)  
	TOPIC=$2
	shift 2
	;;
    -o|--value)  
	CMND=$2
	shift 2
	;;
    -s|--sensor)  
	SENSOR=$2
	shift 2
	;;
    -n|--relaynumber)
	RELNR=$2
	shift 2
	;;
    -r|--realname)  
	REALNAME=$2
	shift 2
	;;
    -d|--debug)
	DEBUG=1
	shift
	;;
    --)
        shift
        break
        ;;
    *)  
	echo "Internal error!" ; exit 1 
	;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

if [ -z $CHANNEL ] ; then
	usage
	exit 1
elif [ -z $TOPIC ] ; then
	usage
	exit 1
fi

if [ -z $REALNAME ] ; then
        REALNAME="$CHANNEL"
fi

# check online
ONLINE=$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $SUB -h $MQHOST -p $MQPORT $MQOPTION -W 10 -C 1 -v -t tele/$TOPIC/LWT | awk '{ print $2 }' )
if [ "x$ONLINE" == "xOnline" ]
then
        AVAILABLE=1 # Status: erreichbar
else
        AVAILABLE=0 # Status: nicht erreichbar
fi
set_CCU_SysVar $AVAILABLE $REALNAME-status
if [ $AVAILABLE -eq 0 ] ; then
	set_CCU_SysVar -100 $REALNAME-RSSI
	logger -i -t $0 -p 3 "Warning: $TOPIC Offline" >> /dev/null 2>&1
	exit 1
fi

if [ "x$CMND" != "x" ] ; then
        set_powercmnd
else
        force_powerstate
fi

get_powerstate


$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $PUB -h $MQHOST -p $MQPORT $MQOPTION -t cmnd/$TOPIC/status -m 5 )
StatusNET=$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $SUB -h $MQHOST -p $MQPORT $MQOPTION -W 5 -C 1 -R -t stat/$TOPIC/STATUS5 )

$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $PUB -h $MQHOST -p $MQPORT $MQOPTION -t cmnd/$TOPIC/status -m 10 )
StatusSNS=$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $SUB -h $MQHOST -p $MQPORT $MQOPTION -W 5 -C 1 -R -t stat/$TOPIC/STATUS10 )

$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $PUB -h $MQHOST -p $MQPORT $MQOPTION -t cmnd/$TOPIC/status -m 11 )
StatusSTS=$( LD_LIBRARY_PATH=$ADDON_DIR/lib && $SUB -h $MQHOST -p $MQPORT $MQOPTION -W 5 -C 1 -R -t stat/$TOPIC/STATUS11 )


IPAddress=$(echo $StatusNET | jq .StatusNET | jq .IPAddress | sed 's/"//g')
set_CCU_SysVar $IPAddress $REALNAME-ipaddr

Signal=$(echo $StatusSTS | jq .StatusSTS | jq .Wifi | jq .Signal | sed 's/"//g')
set_CCU_SysVar $Signal $REALNAME-RSSI

Time=$(echo $StatusSNS | jq .StatusSNS.Time | sed 's/"//g')
set_CCU_SysVar $Time $REALNAME-time


get_ccu_var_info

if [ "x$SENSOR" != "x" ] ; then
	i=1
	OLDIFS=$IFS
	IFS=,
	for value in $SENSOR
	do
		value=$(echo $value | tr '[a-z]' '[A-Z]')
		echo "Sensor$i: $value"
		IFS=$OLDIFS
		get_sensors $value
		i=$((i+1))
	done
	IFS=$OLDIFS
fi

debugmsg

exit 0
