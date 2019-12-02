#!/bin/sh
#
# Borra la imagen
# $1: El directorio de imagen con su ruta completa.
#

SCRIPTDIR=$(dirname "$0")
IMGDIR="$1"

title="Borrado de la imagen"

. "$SCRIPTDIR/lib/dialog.sh"
. "$SCRIPTDIR/lib/utils.sh"
# Obtenemos las variables del código PHP
vars

# Leeamos la descripción de la imagen.
read_desc "$IMGDIR/$descfile"

dialog --yesno "Se borrará la imagen $nombre. ¿Está completamente seguro?" 8 55

if [ $? -eq 0 ]; then
   if msg=$(rm -r "$IMGDIR" 3>&1 1>&2 2>&1); then
      dialog --msgbox "Borrada la imagen $nnombre" 7 45
   else
      error "$msg"
      exit 1
   fi
   rm -f "$tmpdir/$nombre"
else
   dialog --msgbox "Nada que hacer, pues." 7 45
fi
