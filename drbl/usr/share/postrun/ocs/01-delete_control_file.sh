#!/bin/sh
#
# Borra el fichero de control que advertía de la clonación multicast
#

. "`dirname $0`/../../prerun/ocs/utils.sh"

file=`get_tempfile`

if [ -f "$file" ]; then
   echo "Borrando el fichero de control $file"
   rm -f "$file"
else
   echo "ERROR: $file no existe"
fi
