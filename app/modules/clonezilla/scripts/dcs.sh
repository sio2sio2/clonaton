#!/bin/sh
#
# Lanza clonezilla multiserver preparando
# la línea de comandos de drbl-ocs.
# Puede lanzarse en el propio servidor (ver dcs -h).
#

DRBL_PATH="`dirname $0`/../drbl"
DRBL_OCS="$DRBL_PATH/sbin/drbl-ocs"
# Opciones predeterminadas que se pasan al drbl-ocs
# del servidor y el ocs-sr del cliente.
OPTS="--batch
      -g auto
      -e1 auto
      -e2
      -r
      -j2
      -l es_ES.UTF-8"

title="Lanzador de clonación multicast"

SCRIPTDIR=$(dirname $0)
. "$SCRIPTDIR/lib/dialog.sh"
. "$SCRIPTDIR/lib/utils.sh"
vars

PHPUTILS=$(readlink -f "$SCRIPTDIR/../utils.php")
eval "$(php -d error_reporting=E_STRICT -r 'require("'"$PHPUTILS"'");
   echo "lista_aulas=\"".lista_aulas()."\"\n";
')"

help() {
   echo "$(basename $0) [opciones] [operación] [imagen] [dispositivo [...]]
   Lanzador de clonezilla para restauracióon multicast.

+ Opciones:

   -b, --batch                         Obliga a que toda la información se 
                                       proporcione por línea de comandos y
                                       falla en caso contrario.
   -c, --client-to-wait NUM            Número de clientes cuya conexión espera
                                       el servidor antes de comenzar la
                                       restauracion multicast.
   -h, --help                          Muestra esta misma ayuda.
   -i, --mcast-iface   IFACE           Interfaz de escucha para multicast.
   -n, --no-poweroff                   No apaga el servidor al término de la
                                       operación.
   -o, --poweroff                      Apaga el servidor al término de la
                                       operación.
   -p, --post [true|poweroff|reboot]   Orden que se enviará al cliente al fin
                                       de la restauración. \"true\" significa que
                                       que el cliente quedará encendido con la
                                       línea de comandos habilitada..
   -r, --room  AULA                    Aula en la que se desea realizar la
                                       clonación multicast. Es altirnativa a
                                       -i, aunque menos prioritaria.
   -s, --simulate                      Muestra la orden que arranca clonezilla
                                       server, pero no la ejecuta.
   -t, --max-time-to-wait SEGUNDOS     Tiempo máximo en segundos desde la
                                       conexión del primer cliente que esperará
                                       el servidor antes de empezar la
                                       restauracón. Por defecto, 0, que
                                       significa que esperará indefinidamente
                                       hasta que se conecte el número de
                                       clientes especificado con la opción -c.

+ Operación:

   startdistk                          Resataura discos completos.
   startparts                          Restaura particiones individuales.
   stop                                Cancela una restauración ya lanzada.

+ Imagen es el nombre de la imagen que se quiere restaurar, si solo se indica
  un nombre y se buscará en el directorio predeterminado de imágenes. Si se
  indica una ruta completa, se tomará ésta como el directorio que contiene la
  imagen.

  En el caso de que la operación sea "stop" representa la imagen de la que
  se quiere parar el lanzamiento.

+ Dispositivos son aquellos discos (startdisk) o particiones (startparts) que
  se pretenden restaurar.

A menos que se incluya la opción -b, se preguntará mediante cuadros de diálogo
aquellos datos necesarios para completar la orden que no tiene valor
predeterminado.
"
}


#
# Obtiene la red a la que pertenece un aula
# $1: Nombre del aula
#
get_network() {
   echo "$lista_aulas" | grep -oP '(?<=^'"$1"'=)[^,]+(?=,)'
}


#
# Lista las interfaces configuradas y su dirección ip
#
list_ifaces() {
   # A la IP le quitamos la máscara.
   ip -f inet -o addr show | awk '{print $2 "=" substr($4, 0, index($4, "/"))}'
}


#
# Determina si una ip pertenece a una red.
# (requiere python3)
# $1: La dirección ip
# $2: La dirección de red en formato CIDR
# 
# return 0, si pertenece.
ip_in_network() {
   local python=`which python3`
   python=${python:-`which python`}

   $python -c 'import ipaddress as ip; exit(ip.ip_address("'$1'") not in ip.ip_network("'$2'"))' 2>/dev/null
}


#
# Obtiene la interfaz a la que está asociada un aula.
# $1: Aula
#
# return El nombre de la interfaz
#room2iface() {
#   local net x ip
#   net=$(get_network "$1") || return 1
#
#   for x in $(list_ifaces); do
#      ip=${x#*=}
#      if ip_in_network $ip $net; then
#         echo ${x%=*}
#         return 0
#      fi
#   done
#   return 1
#}
room2iface() {
   echo "$lista_aulas" | awk -F"[,=]" '$1 =="'$1'" {print $3}' | grep '.'
}

#
# Obtiene el aula a la que está asociada una interfaz
# $1: Interfaz
#
# return El nombre del aula
#iface2room() {
#   local IFS linea aula net ip=$(list_ifaces | grep -oP '(?<=^'"$1"'=).+$')
#   IFS='
#'
#   for linea in $lista_aulas; do
#      aula=${linea%%=*}
#      net=${linea#*=} ; net=${net%%,*}
#      if ip_in_network $ip $net; then
#         echo $aula
#         return 0
#      fi
#   done
#   return 1
#}
iface2room() {
   echo "$lista_aulas" | awk -F'[,=]' '$3 =="'$1'" {print $1}' | grep '.'
}


#
# Determina si el argumento es un número
# $1: Argumento a comprobar.
#
es_numero() {
   echo "$1" | egrep -q '^[0-9]+$'
}


#
# Nuestra un mensaje de error y acaba el programa.
# $1: El código de error.
# $2: El mensaje de error.
#
eerror() {
   local code=$1
   shift
   echo "$*" >&2
   exit $code
}


#
# Calcula el directorio de la imagen
# $1: El nombre de la imagen o la ruta al directorio de la imagen
#     si es una ruta absoluta.
#
get_imgdir() {
   local image="$1" desc

   # Si empieza por /, es una ruta absoluta.
   [ -z "${1%%/*}" ] && echo "$image" && return 0

   for desc in "$imgdir/$image/$descfile"; do
      read_desc "$desc" x
      [ "$x_nombre" = "$1" ] && dirname "$desc" && return 0
   done
   return 1
}


#
# Lista los discos de una imagen
# $1: La ruta al directorio de la imagen
#
list_disks() {
   cat "$1"/disk
}


#
# Lista las particiones de una imagen
# $1: La ruta al directorio de la imagen
#
list_parts() {
   cat "$1"/parts
}


#
# Comprueba que los dispositivos sean los adecuados. Tienen que ser
# discos si la operación es startdisk o particiones si es startparts
# $1: Operación
# $2: Ruta al directorio de la imagen
# $3, etc.: Los dispositivos.
#
check_devices() {
   local action="$1" imagedir="$2" devices parts
   shift 2

   case $action in
      startdisk)
         devices=$(list_disks "$imagedir")
         ;;
      startparts)
         devices=$(list_parts "$imagedir")
         ;;
      stop) return 0 ;;
      *) eerror 3 "$action: Operación incorrecta";;
   esac

   while [ $# -gt 0 ]; do
      echo "$devices" | grep -qw "$1" || { echo $1; return 1; }
      shift
   done
   return 0
}


#
# Comprueba si la restauración de la imagen está lanzada.
# $1: La imagen.
#
restoring_image() {
   [ -f $(echo "$multifile" | sed -r 's:\{\{image\}\}:'"$1:") ]
}

#
# Comprueba si desde un aula, puede verse una imagen
# $1: El aula
# $2: La visibilidad de la imagen
#
visible_from_room() {
   local aula=$1
   shift
   echo $* | egrep -q '@(?'"$aula"'\b|\*)?(?\s|$)'
}

#
# Lista las imágenes visbles
# $1: Aula desde la que se ven las imágenes (o nada, que implica cualquiera)
# $2: Vacío si quieren listarse todas las imágenes visibles, 0, si quieren
#     listarse sólo las imágenes visibles que no están restaurándose; y
#     1, si lo contrario.
#
# return: Una lista en que cada línea tiene el aspecto:
#
#    '/ruta/a/la/imagen' 'descripción o nombre'
#
list_images() {
   local aula=$1 desc

   for desc in "$imgdir"/*/"$descfile"; do
      read_desc "$desc" x
      [ -n "$aula" ] && ! visible_from_room "$aula" $x_visibilidad && continue
      if [ -n "$2" ]; then
         { [ $2 -eq 0 ] && ! restoring_image $x_nombre; } || \
         { [ $2 -eq 1 ] && restoring_image $x_nombre; } || continue
      fi
      echo "'$(dirname $desc)' '${x_desc:-$x_nombre}'"
   done
}


#
# Lista todas las aulas en que es visible una imagen
# Si no se especifica, se devuelven todas las aulas.
# $1: La ruta al directorio de la imagen
#
# return: Una lista en que cada línea tiene el aspecto:
#
#    aula 'descripción o nombre'
#
list_aulas() {
   local imagedir=$1 linea

   [ -n "$imagedir" ] && read_desc "$imagedir/$descfile" x

   echo "$lista_aulas" | while read linea; do
      aula=${linea%%=*}
      desc=${linea##*,}
      [ -n "$imagedir" ] && ! visible_from_room $aula $x_visibilidad && continue
      iface=$(room2iface "$aula") || continue 
      echo "$iface '${desc:-$aula}'"
   done
}


#
# Pregunta por la imagen que se desea clonar
# $1: Aula desde la que se clona (o nada)
#
# return: El directorio de la imagen
#   + 0: Si se seleccionó una imagen
#   + 1: Si no hay imágenes disponibles
#   + 2: Si se canceló la selección
#
pregunta_imagen() {
   local aula=$1 resp items num

   items=$(list_images "$aula" 0)
   eval set -- $items
   num=$(($#/2))

   case $num in
      0) return 1;;
      1) resp=${items%% *};;
      *) resp=$(dialog --notags --menu "Escoja la imagen a clonar" \
            $(menu_height num) 75 $num "$@") || return 2
         ;;
   esac

   eval echo $resp
}


#
# Pregunta el aula desde la que se piensa clonar
# $1: La ruta de la imagen (o nada)
# $2: El nombre de la imagen
#
# return: El nombre del aula y el código de estado
#   + 0: Si se seleccionó un aula
#   + 1: Si no se puede seleccionar aula, porque la
#        imagen no es visible desde ninguna.
#   + 2: Si se canceló la selección
#
pregunta_aula() {
   local imagedir="$1" image="$2" resp items num leyenda="Seleccione el aula"

   items=$(list_aulas "$imagedir")
   eval set -- $items
   num=$(($#/2))

   [ -z "$items" ] && num=0

   [ -n "$image" ] && leyenda="${leyenda} para clonar $image"

   case $num in
      0) return 1;;
      1) resp=${items%% *};;
      *) resp=$(dialog --menu "$leyenda" $(menu_height num) 75 $num "$@") || return 2
         ;;
   esac

   echo $resp
}


#
# Pregunta los clientes sobre los que se quiere restaurar la imagen
# $1: Aula donde se realiza la clonación
#
pregunta_clientes() {
   local aula="$1" resp
   resp=$(dialog --inputbox "¿Sobre cuántos clientes en *$aula* desea realizar la restauración?" 10 55) || return 2
   es_numero "$resp" || { echo "Se requiere un número natural" && return 1; }
   echo $resp
}


#
# Pregunta el tiempo de temporización
#
pregunta_tiempo() {
   local resp
   resp=$(dialog --inputbox "Temporización (en minutos)" 10 55 "10") || return 2
   es_numero "$resp" || { echo "Se requiere un número entero" && return 1; }
   echo $resp
}


#
# Pregunta la acción que se desea realizar.
#
# return: Imprime una de las tres acciones
#
pregunta_accion() {
   local action="$1" resp

   items="startdisk 'Restaurar discos completos'
          startparts 'Restaurar particiones individuales'
          stop 'Cancelar clonación multicast'"

   eval set -- $items
   dialog --notags --menu "Escoja la operación a realizar" $(menu_height 3) 45 3 "$@"
}


#
# Pregunta qué discos se restaurán (startdisk)
# $1: Ruta al directorio de la imagen
#
pregunta_disks() {
   local imagedir="$1" cylinders heads sectors
   local disks="$(list_disks "$imagedir")" disk items
   local num=$(echo "$disks" | wc -w)

   [ $num -eq 1 ] && echo $disks && return 0

   for disk in $disks; do
      eval $(cat "$imagedir"/$disk-chs.sf)
      # La línea será "sda [~500GB]"
      items=${items:+$items }" $disk [~$((cylinders*heads*sectors/2/1024/1024))G] 0"
   done

   eval set -- $items
   dialog --checklist "Seleccione los discos a restaurar" \
      $(menu_height $num) 45 $num "$@" || return 2
}


#
# Pregunta que particiones se restaurarán (startparts)
# $1: Ruta al directorio de la imagen
#
pregunta_parts() {
   local imagedir="$1"
   local parts="$(list_parts "$imagedir")" part items
   local num=$(echo "$parts" | wc -w)

   [ $num -eq 1 ] && echo $parts && return 0

   while read line; do
      part=$(echo $line | egrep -o '^\w+')
      echo "$parts" | grep -qw "$part" || continue
      # La línea será "sda3 'ntfs :: 850M' 0"
      items=${items:+$items }"$part '$(echo $line | awk '{printf "%6s :: %6s\n", $3, $5}')' 0"
   done < "$imagedir"/blkdev.list

   eval set -- $items
   dialog --checklist "Seleccione las particiones a restaurar" \
      $(menu_height $num) 45 $num "$@" || return 2
}


#
# Averigua qué debe sugerirse sobre el apagado del servidor
#
# return:
#    1, debe apargarse el servidor.
#    0, no debe hacerse.
#
get_server_off() {
   parse_conf x
   [ $x_dhcp_type -ne 2 ]
}


#
# Genera las opciones para drbl-ocs
#
get_opts() {
   local opts="$OPTS -or / -o0 -o1 -x -k -p $post --clients-to-wait $clients --mcast-iface $iface"
   
   [ $time -gt 0 ] && opts="$opts --max-time-to-wait $((time*60))"

   # Para que no se haya comprobación es necesrio añadir la opción -sc0
   [ "$check" != "1" ] && opts="$opts -sc0"

   echo $opts "$action multicast_restore '$imagedir' $devices"
}

#
# Genera las opciones con que debe arrancarse el cliente.
#
get_client_opts() {
   local DRBL_CONF="$DRBL_PATH/etc/drbl-ocs.conf"
   local port=$(grep -oP '(?<=^MULTICAST_PORT=")[0-9]+' "$DRBL_CONF")

   local opts="$(echo $OPTS) -p $post --mcast-port $port"
   [ $time -gt 0 ] && opts="${opts} --max-time-to-wait $time"

   echo "$opts multicast_restore${action#start} $(basename "$imagedir") $devices"
}

# Parámetros
batch=
clients=
iface=
#postaction=poweroff  # Definida en la configuración PHP
#server_off=2         # Definida en la configuración PHP
room=
simulate=
time=0 ; cltime=

action=
imagedir=
devices=

#
# Análisis de argumentos
#
while [ $# -gt 0 ]; do
   case $1 in
      -b|--batch)
         batch=1
         shift
         ;;
      -c|--client-to-wait)
         es_numero "$2" || eerror 2 "$2: Número de clientes inválido"
         [ $2 -gt 0 ] || eerror 2 "El número de clientes debe ser al menos 1"
         clients=$2
         shift 2
         ;;
      -h|--help)
         help
         exit 0
         ;;
      -i|--mcast-iface)
         echo /sys/class/net/* | egrep -q '/'"$2"'\b' || eerror 2 "$2: La interfaz no existe"
         iface="$2"
         shift 2
         ;;
      -o|--poweroff)
         server_off=1
         shift
         ;;
      -n|--no-poweroff)
         server_off=0
         shift
         ;;
      -p|--post)
         [ "$2" = "poweroff" ] || [ "$2" = "reboot" ] || [ "$2" = "true" ] || eerror 2 "$2: Acción desconocida"
         postaction=$2
	 shift 2
         ;;
      -r|--room)
         get_network "$2" > /dev/null || eerror 2 "$2: Aula desconocida"
         room=$2
         shift 2
         ;;
      -s|--simulate)
         simulate=1
         shift
         ;;
      -t|--max-time-to-wait)
         es_numero "$2" || eerror 2 "$2: Tiempo en segundos inválido"
         time=$2
         shift 2
         cltime=1  # Marcamos que se fijó un tiempo.
         ;;
      -*) eerror 2 "$1: Opción desconocida"
         ;;
      *) break
         ;;
   esac
done

if [ -n "$iface" ]; then
   room=$(iface2room "$iface") || eerror 2 "La interfaz no está asociada a ningún aula"
elif [ -n "$room" ]; then
   iface=$(room2iface "$room") || eerror 2 "El aula seleccionada no está asociada a ninguna interfaz"
fi


# Análisis de la operación
if [ -n "$1" ]; then
   [ "$1" = "startdisk" ] || [ "$1" = "startparts" ] || [ "$1" = "stop" ] || \
      eerror 2 "$1: Operación desconocida"
   action=$1
   shift
fi

# Análisis de la imagen
if [ -n "$1" ]; then
   imagedir=$(get_imgdir "$1") || eerror 2 "$1: La imagen no existe"
   shift

   aulas=$(list_aulas "$imagedir")

   [ -n "$room" ] && aulas=$(echo "$aulas" | egrep ^$iface'\b')
   [ -z "$aulas" ] && eerror 2 "La imagen no es visible${room:+ desde $room}"
fi

# Análisis de los dispositivos
if [ $# -gt 0 ]; then
   # ask_user equivale a no poner nada, para forzar la pregunta
   if [ "$*" = "ask_user" ]; then
      shift 1
   else
      dev=$(check_devices "$action" "$imagedir" "$@") || eerror 2 "$dev: Dispositivo inválido o inexistente para la operación ${action:-?}"
   fi
else
   # TODO: Podría verse si sólo hay unn dispositivo posible.
   true
fi

devices=$*


if [ -n "$batch" ]; then
   case "$action" in
      stop) [ -z "$room" ] && eerror 2 "Modo batch: faltan datos";;
      *) { [ -z "$room" ] || [ -z "$clients" ] || [ -z "$imagedir" ] || \
            [ -z "$action" ]  || [ -z "$devices" ]; } && eerror 2 "Modo batch: faltan datos";;
   esac
fi


#
# Completamos los datos necesarios no facilitados en la línea
#


while [ -z "$action" ]; do
   action=$(pregunta_accion "$action") || cancel "¿Desea cancelar el lanzamiento?"
done


while [ -z "$imagedir" ]; do
   imagedir=$(pregunta_imagen "$room")
   case $? in
      0) ;;
      1) error "No hay imágenes disponibles en $room" ; exit 1;;
      2) cancel "¿Desea cancelar la operación?";;
   esac
done
image=$(read_desc "$imagedir/$descfile" x; echo $x_nombre)


while [ -z "$iface" ]; do
   iface=$(pregunta_aula "$imagedir" "$image")
   case $? in
      0) ;;
      1) error "$image no es visible desde ningún aula"; exit 1;;
      2) cancel "¿Desea cancelar el lanzamiento?";;
   esac
done
room=$(iface2room "$iface")


if [ "$action" = "stop" ]; then
   if [ -n "$simulate" ]; then
      echo $DRBL_OCS -or / -o1 --mcast-iface "$iface" stop xxxx "$imagedir"
   else
      $DRBL_OCS -or / -o1 --mcast-iface "$iface" stop xxxx "$imagedir"
   fi
   exit 0
fi


while [ -z "$clients" ]; do
   clients=$(pregunta_clientes "$room")
   status=$?
   [ "$clients" = "0" ] && status=2  # Si clientes=0 se pregunta si se quiere cancelar.
   case $status in
      0) break ;;
      1) error "$clients"
         clientes=
         ;;
      2) cancel "¿Desea cancelar el lanzamiento?";;
   esac
done


while [ -z "$cltime" ]; do
   time=$(pregunta_tiempo "$time")
   case $? in
      0) cltime=1;;
      1) error "$time";;
      2) cancel "¿Desea cancelar el lanzamiento?";;
   esac
done


while [ -z "$devices" ]; do
   case $action in
      startdisk)  devices=$(pregunta_disks "$imagedir") || cancel "¿Desea cancelar el lanzamiento?";;
      startparts) devices=$(pregunta_parts "$imagedir") || cancel "¿Desea cancelar el lanzamiento?";;
      stop)       break;;
      *)          eerror 5 "$action imposible";;
   esac
done
# Quitamos las comillas que añade whiptail a la lista de dispositivos
eval devices=\"$devices\"


while [ "$server_off" = "2" ]; do
   get_server_off
   off=$?
   [ $off -eq 1 ] && default=2
   lapso=$(pregunta_lapso "$default" $off)
   case $? in
      0) break;;
      1) ;;
      2) cancel "¿Desea cancelar el lanzamiento?";;
   esac
done


if [ "$simulate" ]; then
   echo $DRBL_OCS $(get_opts)
   [ -n "$lapso" ] && echo "Se apagará el servidor $lapso segundos después de haber acabado"
else
   eval set -- $(get_opts)
   export DELAY="$lapso" OPTS="`get_client_opts`"
   nohup $DRBL_OCS "$@" > /dev/null 2>&1 &
   dialog --msgbox "Preparada la restauración multicast de $image. Ya puede incorporar clientes." 8 60
fi
