#!/bin/sh
#
# Lista los discos del sistema o muestra ask_user, para
# que cloneezilla pregunta sobre cuáles se desea hacer
# operación.
#
# $1: Cuando es distinto de vacío, se tienen en cuenta
#     también los discos extraíbles.
# $2: Cuando es distinto de vacío, siempre lista los discos
#     en vez de devolver ask_user. Esto hace que clonezilla,
#     haga copia de todos los discos, en vez de preguntar.

# Obtiene la lista de dispositivos que son discos duros
# $1: Si tiene cualquier valor, se añaden los dispositivos
#     móvibles (discos USB, etc.)
get_list() {
   for dev in /sys/block/*/device; do
      [ `cat $dev/type` -eq 0 ] || continue  # Es un disco
      dev=`dirname $dev`
      [ -z "$1" ] && [ `cat $dev/removable` -ne 0 ] && continue
      echo $(basename $dev)
   done
}

list=$(get_list $1)

if [ -z "$2" ] && [ `echo "$list" | wc -w` -gt 1 ]; then
   devices=ask_user
else
   devices=$list
fi

echo '#!/bin/sh

/usr/sbin/ocs-sr "$@" '$devices > /tmp/ocs-sr

chmod +x /tmp/ocs-sr
