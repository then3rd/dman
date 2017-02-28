#!/bin/bash
PATH=/opt/dman:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games:/opt/bin
source dman-client-config.sh
if [[ $? -ne 0 ]] ; then
  echo "Failed to source configuration"
  exit 1
fi

UUID="$(echo -n $(hostname -f)_$(cat /var/lib/dbus/machine-id)|base64)"
if [[ -z ${1+x} ]];then #if no $1
    CURL="$(curl -s "${DMAN_URL}?get=1&id=${UUID}")"
    STATE="$(echo "${CURL}" |awk 'BEGIN { FS = ":" }/state:/{print $2}')"
    #DELTA="$(echo "${CURL}" |awk 'BEGIN { FS = ":" }/delta:/{print $2}')"
    DELTA_HR="$(echo "${CURL}" |awk 'BEGIN { FS = ":" }/delta_h:/{print $2}')"
    STAMP="$(date +%s)"
    
    
    killthings(){
      lsof "${MOUNTDIR}" 2>/dev/null|awk '{if ($2 ~ /^[0-9]/) print $2}'|xargs kill
      #echo "umount ${MOUNTDIR}"|tee -a "$LOGFILE"|bash 2>&1 |tee -a "$LOGFILE"
      #echo "cryptsetup close ${DECRYPT}"|tee -a "$LOGFILE"|bash 2>&1 |tee -a "$LOGFILE"
      umount "${MOUNTDIR}"
      cryptsetup close "${DECRYPT}"
    }
    
    #echo "----$STAMP - $STATE----" >> "$LOGFILE"
    #echo "delta:$DELTA" >> "$LOGFILE"
    
    if [[ $STATE == "DEAD" ]];then
      echo "$STATE for $DELTA_HR"
      killthings
    elif [[ $STATE == "ALIVE" ]];then
      echo "$DELTA_HR remaining $STATE"
    else
      echo "State unknown"
    fi
    #echo "--------" >> "$LOGFILE"
elif [[ "${1}" == "set" ]];then #if $1==set
    if [[ -z ${2+x} ]];then #if $2 null
      CURL="$(curl -s "${DMAN_URL}?set=1&time=${DMAN_DEFAULT_TIMEOUT}&id=${UUID}")"
    else
      CURL="$(curl -s "${DMAN_URL}?set=1&time=${2}&id=${UUID}")"
    fi
    echo "${CURL}"
fi