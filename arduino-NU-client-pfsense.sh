#!/bin/bash

# IP address of the arduino UPS monitor server

arduinoUpsMonitor=10.2.2.120:80/upsStatus

shutdownMessage=shutdown
offlineMessage=offline
onlineMessage=online

shutdownShutdownTime=5

retriveShutdown=`curl -sL --connect-timeout 15 $arduinoUpsMonitor | grep -c $shutdownMessage`
retriveOffline=`curl -sL --connect-timeout 15 $arduinoUpsMonitor | grep -c $offlineMessage`
retriveOnline=`curl -sL --connect-timeout 15 $arduinoUpsMonitor | grep -c $onlineMessage`

checkForSchedualedShutdown=`ps aux | grep shutdown | grep -cv "grep"`

echo Checking for shutdown message

if [ $retriveShutdown -ge 1 ]; then

	if [ $checkForSchedualedShutdown -eq 0 ]; then
	    # Tell user shutdown command was detected

	    wall Shutdown message detected shutting down in $shutdownShutdownTime
        sleep 2
        /sbin/shutdown -p +$shutdownShutdownTime
        sleep 2
    else

        echo Shutdown already schedualed

    fi

elif [ $retriveOffline -ge 1 ]; then

    echo Arduino NU Offline

elif [ $retriveOnline -ge 1 ]; then
	
	# Tell user the ups is online

	echo UPS is reporting online, canceling pending shutdowns

    killall shutdown

        
else

	# Tell user status could not be detected

	echo Status could not be determined

fi