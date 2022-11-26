#!/bin/bash

# Usage arduino-NU-client-linux.sh <ip_address_to_arduinoNU_server> <seconds_offline_before_shutdown>

# Set the ip address as the first passed argument.
arduinoNUIP=$1

# set time offline to shutdown equal to second passed argument
timeOfflineToShutdown=$2

# IP address of the arduino UPS monitor server
arduinoUpsMonitor=$arduinoNUIP/timeOffline

timeOffline=`curl -sL --connect-timeout 15 $arduinoUpsMonitor`

if [ $timeOffline -ge $timeOfflineToShutdown ]; then
    echo Arduino NU has reported UPS is offline for $timeOfflineToShutdown seconds
    echo Shutting down in  10 seconds
    sleep 10
    /sbin/shutdown -P now

elif [ $timeOffline -ge 1 ]; then
    echo Arduino NU has reported UPS is offline for $timeOffline seconds
    echo System will shutdown after Arduino NU reports offline for $timeOfflineToShutdown seconds

elif [ $timeOffline -eq 0 ]; then
    echo Arduino NU has reported UPS is online

else

	# Tell user status could not be detected
	echo Arduino NU status could not be determined

fi