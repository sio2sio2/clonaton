#!/bin/sh
#
# Permite acceder a las variables definidas en el PHP
# No tiene permisos de ejecucíon, porque no debe ejecutarse directamente.
#

CLONEZILLADIR=`dirname $_`/../../../../..
. $CLONEZILLADIR/scripts/lib/utils.sh
vars "/../../../../../config.php"

get_tempfile() {
   local nombre desc visibilidad
   read_desc "$IMGDIR/$descfile"
   echo "$multifile" | sed -r 's:\{\{image\}\}:'"$nombre"':; s:\{\{iface\}\}:'"$IFACE:"
}
