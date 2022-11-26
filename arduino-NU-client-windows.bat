@ echo off

Rem IP Address of the arduino UPS Monitor Server 
Rem     Formated as <ip address>:<port>, or <hostname>:<port>

set arduinoUpsMonServer=10.2.2.120:80/timeOffline
set timeToShutdown=60

echo Arduino Network UPS Monitor Windows Client

Set "MyCommand=curl.exe -sSL --connect-timeout 15 %arduinoUpsMonServer%"
@for /f %%R in ('%MyCommand%') do ( Set response=%%R )

Rem echo %response%

if %response% GEQ %timeToShutdown% (
    echo Arduino NU has been offline for over %timeToShutdown% seconds
    echo Shutting down now
    Msg * Arduino NU has been offline for over %timeToShutdown% seconds. SHUTTING DOWN NOW!!!
    shutdown /s /t 20
) else if %response% GTR 0 (
    echo Arduino NU reports offline for %response% seconds
    echo This system will shut down after Arduino NU reports offline for %timeToShutdown%
    curl.exe -d " " https://hassio.mariotech.net/api/webhook/power-outage-notification-r6kQEuueiAYPemRCWdGFlFNK
    
) else (
    echo Arduino NU reports online
)
