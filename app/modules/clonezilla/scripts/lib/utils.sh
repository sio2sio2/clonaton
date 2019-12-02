#
# Utilidades comunes a los scripts de sh
#

# Obtiene variables del código de php
vars() {
   local PHPCONFIG=$(readlink -f "`dirname $0`${1:-/../config.php}")

   eval $(php -d error_reporting=E_STRICT -r 'require("'"$PHPCONFIG"'");
      echo "ssoodir=".abspath(\SSOODIR)."\n";
      echo "descfile=".clonezilla\DESCIMG."\n";
      echo "post=".clonezilla\MULTI_POSTACTION."\n";
      echo "imgdir=".clonezilla\IMGDIR."\n";
      echo "multifile=".clonezilla\MULTICAST."\n";
      echo "tmpdir=".abspath(\TMPDIR)."\n";
      echo "check=".clonezilla\PRECHECK."\n";
      echo "server_off=".(clonezilla\SERVER_OFF??"2")."\n";
   ')
}

# Lee el fichero de descripción de las imágenes.
# $1: El fichero de descripción.
# $2: prefijo a añadir a las variables.
read_desc() {
   eval $(php -r '$params=json_decode(file_get_contents("'"$1"'"), true);
      echo "'${2:+$2_}'nombre=".$params["nombre"]."\n";
      echo "'${2:+$2_}'desc=\"".$params["desc"]."\"\n";
      echo "'${2:+$2_}'visibilidad=\"".implode(" ", $params["visibilidad"])."\"\n";
   ')
}


join_by() {
   local IFS="$1"
   shift
   echo "$*" 
}


# Pregunta por la visibilidad de la imagen (tipo@aula, *@aula, tipo@* o *@*).
# $1: Tipo
# $2: Aula
# $3: Visibilidad actual
# $4: Visibilidades extra
#
# return:
#    - 0, éxito; 2: cancelación.
#    - Imprime el nombre del usuario
pregunta_visibilidad() {
   local tipo="$1" aula="$2" actual="$3" extra="$4" resp num
   local definidas="'*@$aula' 'Para cualquier cliente en $aula' '*@*' 'Para cualquier cliente en cualquier aula'"
   [ -n "$tipo" ] && definidas="$definidas '$tipo@$aula' 'Exclusiva para clientes $tipo en $aula' '$tipo@*' 'Exclusiva para cliente $tipo en cualquier aula'"

   eval set -- "$definidas"
   num=$(($#/2))

   resp=$(dialog --notags --default-item ${actual:-$tipo@*} --menu "Visibilidad de la imagen" $(menu_height num) 75 $num "$@") || return 2
   extra=$(dialog --inputbox "Indique, si las desea, visibilidades adicionales separadas por espacio" 10 50 "$extra") 

   local iaula itipo
   for v in $extra; do
      iaula=${v#*@}
      itipo=${v%@*}
      [ "${itipo:-*}" = "*" ] || [ "$itipo" = "$tipo" ] || existe_tipo "$itipo" || continue
      [ "${iaula:-*}" = "*" ] || existe_aula "$iaula" || continue
      resp="$resp ${itipo:-*}@${iaula:-*}"
   done

   echo "$resp"
}


es_entero() {
   echo "$1" | grep -Eq '^[0-9]+$'
}


# Establece el lapso de tiempo entre que acaba
# la operación y se apaga el servidor.
# $1: Sugerencia de tiempo.
# $2: 0: Lo lógico es que el servidor no se apage; 1: lo lógico es que se apague.
#
# Imprime el lapso de tiempo escrito.
# return:
#    0: Se indicó el lapso (vacío o número) o se canceló.
#    1: lapso incorrecto o no se confirmó la respuesta.
#    2: Se pulsó ESC.
pregunta_lapso() {
   local resp adv;
   local leyenda="El servidor se apagará tras completar la creación de la imagen. Puede, no obstante, instroducir un tiempo de retraso (en minutos) entre el fin de la creación y el apagado. Si lo deja en blanco o cancela esta operación, el apagado no se llevará a cabo"

   resp=$(dialog --inputbox "$leyenda" 13 65 "$1")
   case $? in
      0) if [ -n "$resp" ] && ! es_entero "$resp"; then
            error "Debe consignar un número o dejar en blanco"
            return 1
         fi;;
      1) ;;
      255) return 2;;
   esac

   # Si no se respondió lo que se esperaba
   if [ -z "$resp" -a $2 -eq 1 ] || [ -n "$resp" -a $2 -eq 0 ]; then
      [ -z "$resp" ] && adv="no "
      dialog --yesno "¿Está seguro de que ${adv}desea apagar?" 7 45 || return 1
   fi
   echo $resp
}


# Permite leer el fichero de configuración
CONFFILE=${CONFFILE:-"/etc/clonaton/clonaton.conf"}

parse_conf() {
   local IFS text pre="$1"
   texto=`sed -r '/^[_[:alnum:]]+\s*=/!d; y:'"'"':":; s:^(\S+)\s*=\s*(.*)$:'"${pre:+${pre}_}\1='\2':" "$CONFFILE"` || return 1
   eval $texto
}
