#!/bin/bash

#James Toebes
#https://james.toebesacademy.com
#james@toebesacademy.com
#place in folder where you want to keep script and files
#run as root on cron.


#Set working directory to here
cd $(dirname $(readlink -f $0))

#Zoom link from https://zoom.us/support/down4j
#Resolve to cuurent location
ZOOMDL=https://zoom.us/client/latest/zoom_x86_64.rpm
ZOOMDL=$(curl -v -I --insecure --silent ${ZOOMDL} 2>/dev/null | grep ^location: | cut -d ' ' -f 2)
ZOOMDL=${ZOOMDL//[^a-zA-Z0-9.\/_:]/}

#Find Current date
DLINFO="$(curl -v -I --insecure --silent ${ZOOMDL} 2>/dev/null | grep ^Last-Modified: | cut  -d ' ' -f 2-)"
#DLINFO=${DLINFO#* }
#DLINFO=${DLINFO%?}

ZOOMDATE=$(date +%s --date="${DLINFO}")
ZOOMFILE=$(basename "${ZOOMDL}" .rpm).${ZOOMDATE}.rpm

if [ ! -f "${ZOOMFILE}" ]
then 
    #New file,  download
    echo ZOOMDL: -${ZOOMDL}-
    echo DLINFO: $DLINFO
    echo Download "${ZOOMFILE}"
    #curl --insecure --silent ${ZOOMDL} -o "${ZOOMFILE}"
    wget -q ${ZOOMDL} -O "${ZOOMFILE}"
    if [ $? -eq 0 ] 
    then
        #Successfully downloaded.  Install
        killall zoom
        dnf upgrade -y "${ZOOMFILE}"
    else
        #Not downloaed successfully.  remove any file
        rm -f "${ZOOMFILE}" >/dev/null
    fi
fi


