@ echo off

REM Usage arduino-NU-client-windows.bat <ip_address_to_arduinoNU_server> <seconds_offline_before_shutdown>

for /f "tokens=1-3*" %%a in ("%*") do (
    REM Set the ip address as the first passed argument.
    set arduinoNUIP=%%a
    REM set time offline to shutdown equal to second passed argument
    set timeOfflineToShutdown=%%b
)

REM IP address of the arduino UPS monitor server
set arduinoNUServer=%arduinoNUIP%/timeOffline

echo Arduino Network UPS Monitor Windows Client
echo ________________________________________________________________
echo Configured settings are as follows
echo ArduinoNU Server Address: %arduinoNUServer%
echo Time offline before shutdown (seconds): %timeOfflineToShutdown%
echo ________________________________________________________________

Set "MyCommand=curl.exe -sSL --connect-timeout 15 %arduinoNUServer%"
@for /f %%R in ('%MyCommand%') do ( Set response=%%R )

Rem echo %response%

if %response% GEQ %timeOfflineToShutdown% (
    echo Arduino NU has been offline for over %timeOfflineToShutdown% seconds
    echo Shutting down now
    Msg * Arduino NU has been offline for over %timeOfflineToShutdown% seconds. SHUTTING DOWN NOW!!!
    REM shutdown /s /t 20
) else if %response% GTR 0 (
    echo Arduino NU reports offline for %response% seconds
    echo This system will shut down after Arduino NU reports offline for %timeOfflineToShutdown%
    
) else if %response% EQU 0 (
    echo Arduino NU reports online
) else (
    echo Could not determine Arduin NU status
)
