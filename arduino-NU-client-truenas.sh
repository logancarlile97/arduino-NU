#!/bin/bash

# IP address of the arduino UPS monitor server
arduinoUpsMonitor=10.2.2.120:80/timeOffline

# time in seconds ups needs to be offline before a shutdown occurs
timeOfflineToShutdown=30

timeOffline=`curl -sL --connect-timeout 15 $arduinoUpsMonitor`

if [ $timeOffline -ge $timeOfflineToShutdown ]; then
    echo Arduino NU has reported UPS is offline for $timeOfflineToShutdown seconds
    echo Shutting down in  10 seconds
    sleep 10
    /sbin/shutdown -p now

elif [ $timeOffline -ge 1 ]; then
    echo Arduino NU has reported UPS is offline for $timeOffline seconds
    echo System will shutdown after Arduino NU reports offline for $timeOfflineToShutdown seconds

elif [ $timeOffline -eq 0 ]; then
    echo Arduino NU has reported UPS is online

else

	# Tell user status could not be detected

	echo Arduino NU status could not be determined

fi