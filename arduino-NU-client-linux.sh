#!/bin/bash

# Usage arduino-NU-client-linux.sh <ip_address_to_arduinoNU_server> <seconds_offline_before_shutdown>

log_date () {
	# logging function formatted to include a date
	echo -e "$(date "+%Y/%m/%d %H:%M:%S"): $1"
}

# Check if PID file aready exists
pidFile=/var/run/$0.pid

if [ -f $pidFile ]; then
    log_date "PID file found. Program is already running."
    log_date "Exiting now"
    exit 1
fi
echo $$ > "$pidFile"
trap "rm -rf $pidFile" EXIT INT KILL TERM

#Make sure that user specified arguments
if [ $# -lt 2 ]; then
    log_date "Expected ip address and/or seconds offline before shutdown"
    log_date "Correct usage: arduino-NU-client-linux.sh <ip_address_to_arduinoNU_server> <seconds_offline_before_shutdown>"
    exit 1
fi

#Make sure the user gave an integer as a second argument
re='^[0-9]+$'
if ! [[ $2 =~ $re ]] ; then
   log_date "Second argument <seconds_offline_before_shutdown> must be an integer" 
   exit 1
fi

# Set the ip address as the first passed argument.
arduinoNUIP=$1

# set time offline to shutdown equal to second passed argument
timeOfflineToShutdown=$2

# IP address of the arduino UPS monitor server
arduinoUpsMonitor="$arduinoNUIP/timeOffline"

timeOffline=`curl -sL --connect-timeout 15 "$arduinoUpsMonitor"`

#Check if curl command failed
if [ $? -ne 0 ]; then
    log_date "Time offline check failed against server: $arduinoUpsMonitor"
    exit 1
fi

if [ $timeOffline -ge $timeOfflineToShutdown ]; then
    log_date "Arduino NU has reported UPS is offline for $timeOfflineToShutdown seconds"
    log_date "Shutting down in  10 seconds"
    sleep 10
    /sbin/shutdown -P now

elif [ $timeOffline -ge 1 ]; then
    log_date "Arduino NU has reported UPS is offline for $timeOffline seconds"
    log_date "System will shutdown after Arduino NU reports offline for $timeOfflineToShutdown seconds"

elif [ $timeOffline -eq 0 ]; then
    log_date "Arduino NU has reported UPS is online"

else

	# Tell user status could not be detected
	log_date "Arduino NU status could not be determined"

fi
read -p "Press ENTER to continue"