#!/bin/sh
#
# Borra la imagen
# $1: El directorio de imagen con su ruta completa.
#

SCRIPTDIR=$(dirname "$0")
IMGDIR="$1"
TIPO=$2
AULA=$3

title="Cambio de la visibilidad"

. "$SCRIPTDIR/lib/dialog.sh"
. "$SCRIPTDIR/lib/utils.sh"
# Obtenemos las variables del código PHP
vars

# Leeamos la descripción de la imagen.
read_desc "$IMGDIR/$descfile"

# Determinamos los tipos de ordenadores y aulas existentes
PHPUTILS=$(readlink -f "$SCRIPTDIR/../utils.php")
eval "$(php -d error_reporting=E_STRICT -r 'require("'"$PHPUTILS"'");
   echo "lista_tipos=\"".lista_tipos()."\"\n";
   echo "lista_aulas=\"".lista_aulas()."\"\n";
')"

existe_tipo() {
   echo "$lista_tipos" | egrep -q "^$1="
}

existe_aula() {
   echo "$lista_aulas" | egrep -q "^$1="
}

#
# Separa la visibilidad que provoca que se vea
# la imagen del resto de visibilidades (extra)
# $1: Tipo al que pertenece la máquina.
# $2: Aula en la que está la máquina.
#
patch_visibilidad() {
   local pvisibilidad itipo iaula

   extra=
   for v in $visibilidad; do
      itipo=${v%@*} ; itipo=${itipo:-*}
      iaula=${v#*@} ; iaula=${iaula:-*}

      v="$itipo@$iaula"

      if [ -z "$pvisibilidad" ] && \
         { [ "$itipo" = "*" ] || [ "$itipo" = "$1" ]; } && \
         { [ "$iaula" = "*" ] || [ "$iaula" = "$2" ]; }; then
         pvisibilidad=$v
      else
         extra="${extra:+$extra }$v"
      fi
   done

   [ -n "$pvisibilidad" ] && visibilidad=$pvisibilidad && return 0

   # La imagen no es visible desde el ordenador, así que
   # se toma como imagen principal, la primera.
   extra=${visibilidad#* }

   if [ "$extra" = "$visibilidad" ]; then
      extra=
   else
      visibilidad=${visibilidad%% *}
   fi

   return 1
}

patch_visibilidad "$TIPO" "$AULA"

# Si la imagen no es visible por el ordenador
# redefinimos el tipo y aula para no alterar la visibilidad
# principal al preguntar
if [ $? -ne 0 ]; then
   TIPO=${visibilidad%@*}
   [ "$TIPO" = "*" ] && TIPO=
   fAULA=${visibilidad#*@}
   [ "$fAULA" != "*" ] && AULA=$fAULA
fi

# Calculamos la nueva visibilidad.
while true; do
   visibilidad=$(pregunta_visibilidad "$TIPO" "$AULA" "$visibilidad" "$extra") && break
   cancel "¿Desea cancelar la operación?"
done

visibilidad=$(echo "$visibilidad" | sed -r 's:\S+:"&":g')

# Modificamos el fichero de descripción.
sed -ri 's;("visibilidad").*;\1: [ '"$(join_by , $visibilidad)"' ];' "$IMGDIR/$descfile"

if [ $? -eq 0 ]; then
   rm -f "$tmpdir/$nombre"
   dialog --title "$title" --msgbox "Visibilidad cambiada" 7 45
else
   error "Imposible alterar la visibilidad"
   return 1
fi
