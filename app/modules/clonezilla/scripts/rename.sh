#!/bin/sh
#
# Renombra la imagen
# $1: El directorio de imagen con su ruta completa.
#

SCRIPTDIR=$(dirname $0)
IMGDIR=$1

title="Redenominación de la imagen"

. "$SCRIPTDIR/lib/dialog.sh"
. "$SCRIPTDIR/lib/utils.sh"
# Obtenemos las variables del código PHP
vars

# Leeamos la descripción de la imagen.
read_desc "$IMGDIR/$descfile"

es_nombre_valido() {
   local dir nombre desc visibilidad
   echo "$1" | egrep -q '^[-[:alnum:]_#.]+$' || { echo "El nombre no es válido" && return 1; }
   for dir in $(dirname "$IMGDIR")/*; do
      [ "$dir" != "$IMGDIR" ] || continue
      read_desc "$IMGDIR/$descfile"
      [ "$1" = "$nombre" ] && echo "El nombre ya existe" && return 1
   done
   return 0
}

chdir=0
original=$nombre
while [ -z "$nnombre" ]; do
   nnombre=$(dialog --inputbox "Indique un nuevo nombre" 10 55 $nombre) || break
   if [ -n "$nnombre" ] && msg=$(es_nombre_valido "$nnombre"); then
      nombre=$nnombre
      desc=$(dialog --inputbox "Descripción" 10 55 "$desc") || { nnombre=; break; }
      dialog --yesno "¿Desea que el directorio se llame como la imagen?" 7 55
      case $? in
         0) if [ -e "$(dirname "$IMGDIR")/$nnombre" ]; then
               error "Existe directorio con nombre $nnombre"
            else
               chdir=1
            fi
            ;;
         1) ;;
         255) nnombre=
              break
              ;;
   
      esac
   else
      error "$msg"
      nombre=${nnombre:-$nombre}
      nnombre=
   fi
done

if [ -n "$nnombre" ]; then
   sed -ri '/"nombre"/s;(:\s*")[^"]+;\1'"$nnombre"';' "$IMGDIR/$descfile"
   sed -ri '/"desc"/s;(:\s*")[^"]+;\1'"$desc"';' "$IMGDIR/$descfile"
   [ $chdir -eq 1 ] && mv "$IMGDIR" "$(dirname "$IMGDIR")/$nnombre"
   rm -f "$tmpdir/$original"
   dialog --msgbox "Modificado nombre a $nnombre" 7 45
else
   dialog --msgbox "Se mantiene el nombre $original" 7 45
fi
