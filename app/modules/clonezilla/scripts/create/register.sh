#!/bin/sh
#
# Registra un nuevo tipo de máquina
#
TIPO=$1
MAC=$2
HOSTSFILE=$3
DESC=$4
LOCALBOOT=${5:+,$5}

# Extrae la parte de la MAC que
# identifica al fabricante (tres primeros pares)
get_vendor() {
   echo "$1" | cut -d: -f1-3 
}

echo $(get_vendor "$MAC")":*:*:*,$TIPO  #$DESC$LOCALBOOT" 2>/dev/null >> "$HOSTSFILE"
