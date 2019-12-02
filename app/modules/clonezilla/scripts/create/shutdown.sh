#!/bin/sh
#
# Apaga el servidor cuando se completa la creación de una imagen
#
# $1: Directorio de la imagen que se crea
# $2: retardo con que se ordena el apagado (en segundos).
# $3: 1, si se debe apagar el servidor a pesar del valor de server_off

FREC=5  # Cada 5 segundos
LOCKDIR=/run/lock/clonaton
LOCKFILE="$LOCKDIR/$$.pid"


. "`dirname $0`/../lib/utils.sh"
vars /../../config.php
parse_conf x

if [ "$3" = "1" ]; then
   server_off=1
elif [ "$server_off" = "2" ]; then
   server_off=
   if [ "$x_dhcp_type" = "2" ]; then
      server_off=1
   fi
fi


[ ! -d "$LOCKDIR" ] && mkdir -m 2775 "$LOCKDIR" && chgrp "$x_group" "$LOCKDIR"
touch "$LOCKFILE"

DELAY=${2:-0}

nohup sh -c '
   while [ -f "'"$1/$descfile.tmp"'" ]; do
      sleep '$FREC'
   done
   sleep '$((DELAY*60))'
   rm -f "'"$LOCKFILE"'"
   [ -z "$(ls -A "'"$LOCKDIR"'")" ] && [ "'$server_off'" = "1" ]  && sudo poweroff
' >/dev/null 2>&1 &
