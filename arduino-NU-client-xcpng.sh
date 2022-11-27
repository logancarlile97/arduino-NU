#!/bin/bash

# all below is script to safely shutdown xcpng
# This script will shutdown all running VMs in a Xen pool, all slave Xen 
# hosts, and eventually the Xen pool master. 
#
# Communication between Xen hosts is required for the sucessfull shutdown
# of all VMs/hosts; ensure that the network infrastructure between Xen 
# hosts does not loose power before this script completes execution. 
#
# This script will only run on the pool master though should be installed
# (along with NUT) on all Xen hosts in the case of a change in master.
#

xcpngShutdown () {

	# Script version number
	version=1.0

	# Seconds until VM clean shutdown times out (seconds until force shutdown initiated)
	vm_shutdown_timeout=600

	# Seconds until VM force shutdown times out (seconds until power reset initiated)
	vm_forcedown_timeout=80

	# Seconds to wait after initiating power reset on VM
	vm_powerreset_timeout=60

	# Seconds until slave host shutdown timeout (seconds until master gives up and shuts itself down)
	xen_slave_timeout=240

	# Log file location
	log_file="/var/log/xcpng-shutdown.log"

	log_date "==============================================================================="
	log_date "Powerdown event recieved from NUT master, initiating shutdown proceedure"
	log_date "xen-shutdown.sh version $version"
	log_date "==============================================================================="

	# Get UUIDs of all running VMs
	vm_uuids=( $(xe vm-list power-state=running is-control-domain=false --minimal | tr , "\n" ) )

	# Shutdown each VM
	for uuid in "${vm_uuids[@]}"; do
		vm_name="$(xe vm-param-get uuid=$uuid param-name=name-label)"
		log_date "Shutting down VM $vm_name (UUID: $uuid)"
		xe vm-shutdown uuid=$uuid &
		sleep 1
	done

	# Start timer for timeout
	start_time=$SECONDS

	# Loop until all VMs shutdown or timeout
	sleep 10
	while [ $(( SECONDS - start_time )) -lt $vm_shutdown_timeout ]; do
		vm_uuids=( $(xe vm-list power-state=running is-control-domain=false --minimal | tr , "\n" ) )
		if [ ${#vm_uuids[@]} -eq 0 ]; then
			# If all VMs shutdown, shutdown hosts
			shutdown_xenhosts
			exit
		else
			log_date "Not all VMs shutdown, continuing to wait..."
			sleep 10
		fi
	done

	# Attempt to force shutdown any VMs still running after clean shutdown timeout
	vm_uuids=( $(xe vm-list power-state=running is-control-domain=false --minimal | tr , "\n" ) )
	for vm_uuid in "${vm_uuids[@]}"; do
		vm_name="$(xe vm-param-get uuid=$vm_uuid param-name=name-label)"
		log_date "Shutdown timeout, attempting to force down VM $vm_name (UUID: $vm_uuid)"
		xe vm-shutdown uuid=$vm_uuid force=true &
		sleep 1
	done
	sleep $vm_forcedown_timeout

	# Initiate power reset on any VMs still running after clean and force shutdown timeout
	vm_uuids=( $(xe vm-list power-state=running is-control-domain=false --minimal | tr , "\n" ) )
	for vm_uuid in "${vm_uuids[@]}"; do
		vm_name="$(xe vm-param-get uuid=$vm_uuid param-name=name-label)"
		log_date "VM $vm_name (UUID: $vm_uuid) is still running, initiating power reset"
		xe vm-reset-powerstate uuid=$vm_uuid force=true &
		sleep 1
	done
	sleep $vm_powerreset_timeout 

	# Procede with shutting down hosts
	shutdown_xenhosts

	exit	
}

shutdown_xenhosts () {
	# Get UUID of all hosts
	xen_uuids=( $(xe host-list --minimal | tr , "\n" ) )

	# Get UUID of this host (master)
	xen_master_uuid=$( cat /etc/xensource-inventory | grep -i installation_uuid | awk -F"'[[:blank:]]*" '{print $2}' )

	# Get UUID of slave hosts
	xen_slave_uuids=()
	for uuid in ${xen_uuids[@]}; do
		if [[ $uuid != $xen_master_uuid ]]; then
			xen_slave_uuids+=($uuid)
		fi
	done

	# Shutdown all slave hosts
	for uuid in ${xen_slave_uuids[@]}; do
		slave_name=$(xe host-param-get uuid=$uuid param-name=name-label)
		log_date "Disabling slave host $slave_name (UUID: $uuid)"
		xe host-disable uuid=$uuid
		sleep 1
		log_date "Shutting down slave host $slave_name (UUID: $uuid)"
		xe host-shutdown uuid=$uuid &
		sleep 1
	done

	# Start timer for timeout
	start_time=$SECONDS

	# Loop until all slave hosts do not respond to ping or timeout
	sleep 10
	for uuid in ${xen_slave_uuids[@]}; do
		if [ $(( SECONDS - start_time )) -lt $xen_slave_timeout ]; then
			while true; do
				ping -c 1 $(xe host-param-get uuid=$uuid param-name=address) > /dev/null 2> /dev/null
				# If slave replies to ping
				if [ $? -eq 0 ]; then
					log_date "Not all slave hosts shutdown, continuing to wait..."
					sleep 10
					continue
				else
					sleep 2
					break
				fi
			done
		else
			log_date "Slave host shutdown timeout, proceeding with master host shutdown"
		fi
	done

	# Shutdown master host
	xen_master_name="$(xe host-param-get uuid=$xen_master_uuid param-name=name-label)"
	log_date "Disabling master host $xen_master_name (UUID: $xen_master_uuid)"
	xe host-disable uuid=$xen_master_uuid
	sleep 1
	log_date "Shutting down master host $xen_master_name (UUID: $xen_master_uuid)"
	xe host-shutdown uuid=$xen_master_uuid
	sleep 1
}

log_date () {
	# logging function formatted to include a date
	echo -e "$(date "+%Y/%m/%d %H:%M:%S"): $1" >> "$log_file" #2>&1
}

# Usage arduino-NU-client-linux.sh <ip_address_to_arduinoNU_server> <seconds_offline_before_shutdown>

# Set the ip address as the first passed argument.
arduinoNUIP=$1

# set time offline to shutdown equal to second passed argument
timeOfflineToShutdown=$2

# IP address of the arduino UPS monitor server
arduinoNUServer=$arduinoNUIP/timeOffline

timeOffline=`curl -sL --connect-timeout 15 $arduinoNUServer`

if [ $timeOffline -ge $timeOfflineToShutdown ]; then
    echo Arduino NU has reported UPS is offline for $timeOfflineToShutdown seconds
    echo Shutting down in  10 seconds
    sleep 10
    
    # Check that host has master role if not master master will initiate shutdown
    role="$(more /etc/xensource/pool.conf)"
    if [[ $role == *"master"* ]]; then
        xcpngShutdown
    fi

elif [ $timeOffline -ge 1 ]; then
    echo Arduino NU has reported UPS is offline for $timeOffline seconds
    echo System will shutdown after Arduino NU reports offline for $timeOfflineToShutdown seconds

elif [ $timeOffline -eq 0 ]; then
    echo Arduino NU has reported UPS is online

else
	# Tell user status could not be detected
	echo Arduino NU status could not be determined

fi