#!/bin/bash
source dman-cgi-config.sh
if [[ $? -ne 0 ]] ; then
  echo "Failed to source configuration"
  exit 1
fi

function displaytime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%dd ' $D
  (( $H > 0 )) && printf '%dh ' $H
  (( $M > 0 )) && printf '%dm ' $M
  (( $D > 0 || $H > 0 || $M > 0 ))
  printf '%ds\n' $S
}

# (internal) routine to store POST data
function cgi_get_POST_vars()
{
    # only handle POST requests here
    [ "$REQUEST_METHOD" != "POST" ] && return

    # save POST variables (only first time this is called)
    [ ! -z "$QUERY_STRING_POST" ] && return

    # skip empty content
    [ -z "$CONTENT_LENGTH" ] && return

    # check content type
    # FIXME: not sure if we could handle uploads with this..
    [ "${CONTENT_TYPE}" != "application/x-www-form-urlencoded" ] && \
        echo "bash.cgi warning: you should probably use MIME type "\
             "application/x-www-form-urlencoded!" 1>&2

    # convert multipart to urlencoded
    local handlemultipart=0 # enable to handle multipart/form-data (dangerous?)
    if [ "$handlemultipart" = "1" -a "${CONTENT_TYPE:0:19}" = "multipart/form-data" ]; then
        boundary=${CONTENT_TYPE:30}
        read -N $CONTENT_LENGTH RECEIVED_POST
        # FIXME: don't use awk, handle binary data (Content-Type: application/octet-stream)
        QUERY_STRING_POST=$(echo "$RECEIVED_POST" | awk -v b=$boundary 'BEGIN { RS=b"\r\n"; FS="\r\n"; ORS="&" }
           $1 ~ /^Content-Disposition/ {gsub(/Content-Disposition: form-data; name=/, "", $1); gsub("\"", "", $1); print $1"="$3 }')

    # take input string as is
    else
        read -N $CONTENT_LENGTH QUERY_STRING_POST
    fi

    return
}

# (internal) routine to decode urlencoded strings
function cgi_decodevar()
{
    [ $# -ne 1 ] && return
    local v t h
    # replace all + with whitespace and append %%
    t="${1//+/ }%%"
    while [ ${#t} -gt 0 -a "${t}" != "%" ]; do
        v="${v}${t%%\%*}" # digest up to the first %
        t="${t#*%}"       # remove digested part
        # decode if there is anything to decode and if not at end of string
        if [ ${#t} -gt 0 -a "${t}" != "%" ]; then
            h=${t:0:2} # save first two chars
            t="${t:2}" # remove these
            v="${v}"`echo -e \\\\x${h}` # convert hex to special char
        fi
    done
    # return decoded string
    echo "${v}"
    return
}

# routine to get variables from http requests
# usage: cgi_getvars method varname1 [.. varnameN]
# method is either GET or POST or BOTH
# the magic varible name ALL gets everything
function cgi_getvars()
{
    [ $# -lt 2 ] && return
    local q p k v s
    # get query
    case $1 in
        GET)
            [ ! -z "${QUERY_STRING}" ] && q="${QUERY_STRING}&"
            ;;
        POST)
            cgi_get_POST_vars
            [ ! -z "${QUERY_STRING_POST}" ] && q="${QUERY_STRING_POST}&"
            ;;
        BOTH)
            [ ! -z "${QUERY_STRING}" ] && q="${QUERY_STRING}&"
            cgi_get_POST_vars
            [ ! -z "${QUERY_STRING_POST}" ] && q="${q}${QUERY_STRING_POST}&"
            ;;
    esac
    shift
    s=" $* "
    # parse the query data
    while [ ! -z "$q" ]; do
        p="${q%%&*}"  # get first part of query string
        k="${p%%=*}"  # get the key (variable name) from it
        v="${p#*=}"   # get the value from it
        q="${q#$p&*}" # strip first part from query string
        # decode and assign variable if requested
        [ "$1" = "ALL" -o "${s/ $k /}" != "$s" ] && \
            export "$k"="`cgi_decodevar \"$v\"`"
    done
    return
}

# register all GET and POST variables
cgi_getvars BOTH ALL

if [[ ! ${1} == "SH" ]];then
  echo -e "Content-type: text/html\n"
  #echo -e "Content-type: text/html\n\n"
fi

if [[ $hr -eq 1 ]];then
cat <<EOF
<html>
<body>
<pre>
EOF
fi

if [[ ! -z ${id+x} ]] || [[ ! -z ${id_hr+x} ]];then #ID or ID_HR is not empty
  if [[ ! -z ${id_hr+x} ]];then #human-input id not empty
    UUID="${id_hr}"
  else
    UUID="$(echo -n ${id}|base64 -d)"
  fi
  UUID_MD5="$(echo -n ${UUID}|md5sum|cut -f1 -d' ')"
  CUR_EPOCH="$(date +%s)"

  if [[ $get -eq 1 ]] && [[ ! -f "${DMAN_UUID_ROOT}/dman.${UUID_MD5}" ]] ;then #If get but doesn't exist
    echo "ERR: Host not set"
    exit
  fi

  if [[ $set -eq 1 ]];then #If set=1
    if [ -z ${time+x} ];then #if no time is specified, use a defaault
      TIMEOUT="$((60*60*24*2))"  #Default timeout of 2days
    else  #use timeout from GET
      TIMEOUT="$((${time}))"
    fi
    FUTURE_EPOC="$(( TIMEOUT + CUR_EPOCH ))" 
    #uptime
    echo "set:$set"
    echo "set_time:${time}";
    echo "timeout:${TIMEOUT}" 
    echo "uuid:${UUID}"
    echo "uuid_md5:${UUID_MD5}"
    echo "future_epoc:${FUTURE_EPOC}"
    echo -n "${UUID}" > "${DMAN_UUID_ROOT}/dman.${UUID_MD5}"
    touch -a --time=mtime --date="@${FUTURE_EPOC}" "${DMAN_UUID_ROOT}/dman.${UUID_MD5}"
  fi
 
  if [[ $get -eq 1 || $set -eq 1 || $status -eq 1 ]];then
    DMAN_MTIME="$(stat -c %Y "${DMAN_UUID_ROOT}/dman.${UUID_MD5}")"
    TIME_DIFF="$((DMAN_MTIME - CUR_EPOCH))" #Delta between current time and touched file. +/-
    echo "time_diff:$TIME_DIFF"
    if [[ ${CUR_EPOCH} -lt ${DMAN_MTIME} ]];then #If current time is less than the future-dated file epoch
      COUNTER="$(( DMAN_MTIME - CUR_EPOCH   ))" #how much time is left
      echo "state:ALIVE"
    else
      COUNTER="$(( TIME_DIFF - TIMEOUT ))" #how much time has passed since death.
      echo "state:DEAD"
    fi
    echo "delta:$COUNTER"
    echo "delta_h:$(displaytime $(echo "${COUNTER}"|sed 's/-//'))"
    echo "dman_mtime:${DMAN_MTIME}"
    echo "cur_epoch: ${CUR_EPOCH}"
  fi
else
  if [[ ${1} == "SH" ]] || [[ $report -eq 1 && -z ${set+x} && -z ${get+x} ]];then
    #QUERY_STRING='get=1&id_hr=kbailey0.lab.novell.com_167f83f77aa1cef99d4bb33e58924203'
    QUERY_STRING="${2}"
    CUR_EPOCH="$(date +%s)"
    FILES="${DMAN_UUID_ROOT}/*"
    for f in ${FILES}
    do
      echo -n 'uuid:'
      cat "${f}"
      DMAN_MTIME="$(stat -c %Y "${f}")"
      TIME_DIFF="$((DMAN_MTIME - CUR_EPOCH))" #Delta between current time and touched file. +/-
      echo "time_diff:$TIME_DIFF"
      if [[ ${CUR_EPOCH} -lt ${DMAN_MTIME} ]];then #If current time is less than the future-dated file epoch
        COUNTER="$(( DMAN_MTIME - CUR_EPOCH   ))" #how much time is left
        echo "state:ALIVE"
      else
        COUNTER="$(( TIME_DIFF - TIMEOUT ))" #how much time has passed since death.
        echo "state:DEAD"
      fi
      echo "delta:$COUNTER"
      echo "delta_h:$(displaytime $(echo "${COUNTER}"|sed 's/-//'))"
      echo "dman_mtime:${DMAN_MTIME}"
      echo "cur_epoch: ${CUR_EPOCH}"
      echo "--"
    done
  fi
fi

if [[ $hr -eq 1 ]];then
cat <<EOF
</pre>
</body>
</html>
EOF
fi 