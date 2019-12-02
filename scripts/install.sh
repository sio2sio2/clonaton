#!/bin/sh
#
# Instalador de clonaton
#

HTTPNAME=pxeserver
APPDIR=/usr/local/share/clonaton
TFTPDIR=/srv/tftp
IMGDIR=/srv/nfs/images
CONFFILE=/etc/clonaton/clonaton.conf
APPGROUP=clonaton
LIBDIALOG=modules/clonezilla/scripts/lib/dialog.sh

# Dominio de 1er nivel
DOMAIN1=${DOMAIN1:-"info"}
DNSSERVER=${DNSSERVER:-"1.1.1.1"}
WWWUSER=${WWWUSER:-"www-data"}  # Puede cambiar entre distribuciones.
PHP_SOCKET=${PHP_SOCKET:-"/var/run/php/php7.3-fpm.sock"}
SLITAZ_URL=${SLITAZ_URL:-"http://mirror1.slitaz.org/iso/rolling/slitaz-rolling-core.iso"}
CLONEZILLA_URL=${CLONEZILLA_URL:-"https://osdn.net/dl/clonezilla/clonezilla-live-2.6.4-10-i686.iso"}
MEMTEST_URL=${MEMTEST_URL:-"https://www.memtest.org/download/5.01/memtest86+-5.01.bin.gz"}
LOGFILE="/var/log/clonezilla.log"


help() {
   echo "$(basename $0) [opciones]
   Instala y configura clonatón.

Opciones:

 -c|--compact                Compactar los ítems del menú.
 -d|--appdir    <DIR>        Directorio de instalación del programa.
 -e|--expert                 Habilita el modo experto en la configuración.
 -f|--tftpdir   <DIR>        Directorio compartido por TFTP.
 -F|--force                  Forzar instalación sin probar a detectar si
                             existe una previa.
 -G|--graphic                Menú en modo gráfico.
 -g|--group     <GRUPO>      Grupo capaz de realizar clonaciones.
 -h|--help                   Muestra esta misma ayuda.
 -H|--hide-items             No mostrar los items deshabilitados.
 -i|--imgdir    <DIR>        Directorio donde se guardará las imágenes.
 -l|--loose                  Descompactar el menú.
 -m|--show-menu              Mostrar siempre el menú de arranque por red.
 -M|--sysdir    <DIR>        Directorio donde se encuentran los módulos
                             de syslinux.
 -M32|--sysdir32    <DIR>    Directorio donde se encuentran los módulos
                             de syslinux (efi32)
 -M64|--sysdir64    <DIR>    Directorio donde se encuentran los módulos
                             de syslinux (efi64)
 -N|--no-ssoo                No prepara los directorios de ssoo (p.e.
                             descargando slitaz o clonezilla)
 -n|--httpname  <NOMBRE>     Nombre para el acceso HTTP al servidor.
 -P|--nbpfile    <DIR>       Directorio donde se encuentran lpxelinux.0
 -P32|--nbpfile32   <DIR>    Directorio donde se encuentran syslinux.efi)
 -P64|--nbpfile64   <DIR>    Directorio donde se encuentran syslinux.efi)
 -r|--root      <DIR>        Toma como raíz del sistema el directorio en
                             vez de /.
 -s|--shiftkey               No mostrar el menú a menos que se fuerce su
                             activación durante el arranque.
 -S|--show-items             Mostrar ítems, aunque estén deshabilitados.
 -t|--timeout   <SEGUNDOS>   Temporización del menú (en segundos).
 -T|--textmenu               Menú en modo texto.
 -w|--no-networks            Deja sin dar nombre a las redes.

Los aspectos que no se especifiquen en la línea de órdenes, se preguntarán
a través de cuadros de diálogo.
"
}


eerror() {
   echo "$2" >&2
   exit $1
}


soy_root() {
   [ `id -u` -eq 0 ]
}


es_grupo_valido() {
   echo "$1" | grep -Eq '^[-[:alnum:]]+$'
}


es_dominio_valido() {
   echo "$1" | grep -Eq '^[[:alnum:]]([-.[:alnum:]]*[[:alnum:]])?$'
}

es_ip() {
   local ip="$1" byte IFS
   echo "$ip" | grep -Eq "^(?[0-9]+\.){3}[0-9]+$" || return 1
   IFS="."
   for byte in $ip; do
      [ "$byte" -ge 0 ] && [ "$byte" -le 255 ] || return 1
   done
}


es_nombre_valido() {
   es_grupo_valido "$1"
}


es_numero_entero() {
   echo "$1" | grep -Eq '^\d+$'
}

#
# Comprueba si el directorio raiz es válido
#
es_root_valida() {
   [ -z "$root" ] || [ -d "$root" ]
}

#
# Detecta si ya se realizó la instalación
#
is_installed() {
   [ -f "$CONFFILE" ] || return 1
   parse_conf old  	# Leemos el fichero de configuración
   [ -d "$old_appdir" ]
}

. "`dirname "$0"`/parse_conf.sh"


basedir="`dirname $0`/../app"
is_installed && basedir="$old_appdir"

title="Configurador de clonatón"
. "$basedir/$LIBDIALOG"


#
# Comprueba el servidor DHCP instalado
# return:
#    + 0: No hay servicio; 1, sí lo hay.
#    + Imprime el nombre del servidor instalado.
#           (https://github.com/brgl/busybox/blob/master/examples/udhcp/udhcpd.conf)
#      Pueden imprimir varios, si hay instalados varios.
#
check_dhcp_server() {
   local ret=1

   which dnsmasq dhcpd udhcpd | grep -oP '(?<=/)[^/]+$'
}


#
# Comprueba si debe estar presente en la configuración
# un determinado servidor DHCP.
# $1: La cadena que contiene los servidores presentes
# $2: El servidor (dhcpd, dnsmasq, udhcpd)
#
is_present() {
   echo "$1" | grep -wq "$2"
}


#
# Determina el caso con el que funcionará el equipo:
# return:
#   0: DHCP+PXE todo en uno.
#   1: DHCP, PXE en la misma máquina pero separados.
#   2: proxyDHCP
#   3: No hay ningún servidor instalado
#
#
#   Imprime la lista de servidores DHCP instalados.
#
get_pxe_type() {
   local server status num

   server=`check_dhcp_server`
   status=$?
   num=`echo $server | wc -w`

   if [ $status -eq 0 ]; then
      echo $server
      if is_present "$server" "dnsmasq"; then
         # Si sólo está instalado DNSmasq debe preguntarse
         # si actúa proprocionando también DHCP
         [ $num -eq 1 ] && { get_dnsmasq_role "Sólo se encuentra instalado DNSmasq. Escoja cómo actuará:"; return $?; }
         return 1
      else
         return 0
      fi
   else
      return 3 
   fi
}


#
# Pregunta por el rol que desempeñará DNSmasq
# $1: La leyenda que debe mostrarse
#
# return: 
#    + 0. DHCP+PXE todo en uno.
#    + 2. proxyDHCP
#
get_dnsmasq_role() {
   local resp;
   while true; do
      resp=$(dialog --notags --menu  "$1" `menu_height 2 3` 55 2 0 "Todo en uno (DHCP/PXE integrados)" 2 "Servidor independiente PXE")
      case $resp in
         0|2) return $resp;;
         "") # Se produjo una cancelación de la operación
            cancel "¿Desea abandonar la instalación y configuración?";;
      esac
   done
}


get_tftp_server() {
   local server
   which in.tftpd >/dev/null || return 1
   server=`in.tftpd -V | grep -oP '^.+fftpd'`
   # tftpd carece -V.
   echo "${server:-tftpd}"
   return 0
}


#
# Intenta averiguar el directorio donde
# se encuentran los módulos de syslinux
# $1: Arquitectura (bios, efi32, efi64)
# $2: Sugerencia.
#
check_syslinux() {
   local dir arch="$1"

   # Para debian y fedora
   for dir in "$2" "/usr/lib/syslinux/modules/$arch" /usr/share/syslinux/modules/"$arch"; do
      [ -d "$dir" ] && echo "$dir" && return 0
   done
   return 1
}

#
# Intenta averiguar la ruta del nbp (lpxelinux.0 o syslinux.efi)
# $1: Arquitectura.
# $2: Sugerencia.
#
check_nbp() {
   local nbp arch="$1"

   case "$arch" in
      bios)
         nombre=lpxelinux.0
         ;;
      efi32|efi64)
         nombre=syslinux.efi
         ;;
   esac

   # Para debian y fedora
   for nbp in "$2" "/usr/lib/PXELINUX/$nombre" "/usr/lib/SYSLINUX.EFI/$arch/$nombre" "/usr/share/syslinux/$arch/$nombre"; do
      [ -f "$nbp" ] && echo "$nbp" && return 0
   done
   return 1
}


#
# Obtiene las redes a la que está conectada la máquina
# return:
#    192.168.1.0/24,eth0,192.168.1.1
#    192.168.2.0/24,eth1,192.168.2.1
#
get_networks() {
   local python
   python=$(which python3 || which python)

   ip -o -f inet addr show | awk '$2 != "lo" {print $2, $4}' | $python -c '
import sys
from ipaddress import IPv4Interface as IPv4
for line in sys.stdin:
   iface, ip = line.split()
   print("{!s},{},{!s}".format(IPv4(ip).network, iface, IPv4(ip).ip))'
}


#
# Extrae las redes definidas en el fichero de configuración
# $1: El fichero donde se definen las redes.
# return:
#     CIDR,nombre,Descripción de la red
#
parse_networks() {
   awk -F, -v OFS=, '$0 !~ /^\s*#/ {sub(/[ \t]*#.+$/,""); print $2, $1, $4}' "$1"
}

# Devuelve todas las redes por las que hay que preguntar
# $1: El fichero donde se definen las redes
# return:
#   iface,ip,net,nombre,descripción
#
# Si la iface está vacía es que la máquina ya no está conectada a la red.
list_networks() {
   local from_file from_ifaces="`get_networks`"
   local n ip IFS ni
   [ -f "$1" ] && from_file=`parse_networks "$1"`

   IFS='
'
   for n in $from_file; do
      ip=${n%%,*}
      ni=`echo "$from_ifaces" | grep -E ^"$ip"`
      if [ -n "$ni" ]; then
         iface=${ni#*,}
      else
         iface=","
      fi
      echo "$iface,$n"
   done

   for n in $from_ifaces; do
      ip=${n%%,*}
      echo "$from_file" | grep -Eq ^"$ip" && continue
      echo ${n#*,},$ip
   done
}


#
# Procesa una de las líneas que devuelve la función anterior
# de manera que devuelve definiciones de variables para cada campo
# $1: La línea
# $2: Prefijo para la definición de las variables
#
parse_netinfo() {
   local prefix="${2:+$2_}" IFS value name
   local fields="iface,ip,net,aula,desc"

   IFS=","
   for value in $1; do
      name=${fields%%,*} ; fields=${fields#*,}
      echo "$prefix$name=\"$value\""
   done
}


#
# Pregunta el nombre que tendrá el servidor.
#
pregunta_nombre() {
   local resp

   resp=$(dialog --inputbox "Nombre del servidor (sin dominio). Puede proporcionar una IP, pero, cuando el servidor conecta con varias redes, es recomendable hacerlo a través de un nombre, lo cual, a menos que use DNSmasq, exige la presencia de un servidor DNS adicional:" 12 55 "$1") || return 2
   echo "$resp"
   es_ip "$resp" || es_nombre_valido "$resp"
}


#
# Pregunta el directorio de instalación
#
pregunta_appdir() {
   local resp

   resp=$(dialog --inputbox "Directorio de instalación:" 7 45 "$1") || return 2
   echo "$resp"
   # No hacemos ninguna comprobación
}


#
# Pregunta el directorio compartido por TFTP
#
pregunta_tftpdir() {
   local resp
   local leyenda="La aplicación necesita conocer cuál es el directorio compartido por TFTP."

   [ -n "$2" ] || leyenda="$leyenda Recuerde que debe instalar un servidor más tarde."
   resp=$(dialog --inputbox "$leyenda" 9 55 "$1") || return 2
   echo "$resp"
}


#
# Pregunta el directorio de imágenes
#
pregunta_imgdir() {
   local resp leyenda
   leyenda="Las imágenes reultantes de la clonación requieren ser compartidas por NFS. Indique el directorio:"

   resp=$(dialog --inputbox "$leyenda" 8 55 "$1") || return 2
   echo "$resp"
   # No hacemos ninguna comprobación
}


# Obtiene la información para escribir etc/networks
# $1: Fichero con información sobre redes.
#
# return:
#   Devuelve el contenido del nuevo fichero etc/networks
#
pregunta_redes() {
   local line iface net nombre desc sugerencia

   dialog --msgbox "Para la aplicación cada red representa un aula a la que hay que asignar un nombre y, opcionalmente, una descripción. A continuación se le preguntará sobre aquellas detectadas automáticamente. Si quiere hacer alguna corrección o adición puede editar el fichero $appdir/etc/networks" 12 55

   list_networks "$1" | while read line; do
      eval "$(parse_netinfo "$line")"

      leyenda="Indique un nombre para el aula correspondiente a la red $net"
      if [ -n "$iface" ]; then
         leyenda="$leyenda conectada a través de la interfaz $iface."
      else
         leyenda="$leyenda. ¡Atención! Esta red no parece ya existir."
      fi
      leyenda="$leyenda Deje en blanco el campo para hacerla desaparecer."
      while true; do
         sugerencia=$aula
         aula=$(dialog --inputbox "$leyenda" 11 55 "$sugerencia") || return 2
         if [ -z "$aula" ] || es_nombre_valido "$aula"; then
             break
         fi
      done

      [ -z "$aula" ] && continue
      desc=$(dialog --inputbox "Añada una descripción adecuada" 7 55 "$desc") || return 2
      echo "$iface,$ip,$net,$aula,$desc"
      aula=
      desc=
   done
   return $?
}


#
# Obtiene el dominio de nivel superior al aula
# $1: Sugerencia
#
# return: El nombre del dominio de nivel superior
#
pregunta_dominio() {
   local resp

   resp=$(dialog --inputbox "Al encontrarse cada una en una red distinta, las aulas tienen asignado un dominio cuyo nivel inferior es el nombre de aula. Por ejemplo, si introduce aquí 'mioficina.com', el dominio del aula de nombre 'taller' será 'taller.mioficina.com'. Téngalo en cuenta si configura el DNS por su cuenta. Introduzca el nombre del nivel superior:" 13 55 "$1") || return 2
   echo "$resp"
   es_dominio_valido "$resp"
}

#
#
# Pregunta el grupo que tendrá permisos para realizar clonaciones
# $1: Sugerencia
#
pregunta_grupo() {
   local resp
   resp=$(dialog --inputbox "¿Qué grupo tendrá permisos para realizar clonaciones?" 8 55 "$1") || return 2
   echo "$resp"
   es_grupo_valido "$resp"
}


#
# Pregunta el tipo de menú de syslinux (de texto o gráfico)
# $1: Valor predeterminado
#
pregunta_menu() {
   local default
   [ -n "$1" ] && default="--default-item $1"
   dialog --notags --menu "Tipo de menú de arranque" `menu_height 2` 45 2 menu "Menú de texto" vesamenu "Menú gráfico" || return 2
}


#
# Pregunta si se desea mostrar el menú sólo si Caps-Lock
# está activo o se pulsa Alt/Shift
# $1: Valor predeterminado
#
pregunta_shiftkey() {
   local default="--defaultno"
   [ "$1" = "0" ] && defaultw=""
   dialog --yesno $default --yes-button "Siempre" --no-button "Caps-Lock" "¿Desea que el menú de muestre en cualquier caso o sólo si se activa Caps-Lock?" 8 55
}


#
# Pregunta cuál debe ser la temporización del menú
# $1: Valor predeterminado
#
pregunta_temp() {
   dialog --inputbox "Temporización (en segundos) del menú" 7 45 "$1" || return 2
}


#
# Pregunta si se desean mostrar las entradas inhábiles
# $1: Valor predeterminado
#
pregunta_visible() {
   local default="--defaultno"
   [ "$1" = "0" ] && default=""
   dialog --yesno $default --yes-button "Ocultar" --no-button "Desactivar" "¿Qué desea hacer con las entradas del menú que no cumplen dependencias?" 8 45
}


#
# Pregunta si se desea compactar el menú
#
pregunta_compact() {
   local default
   [ "$compact" = "0" ] && default="--defaultno"
   dialog --yesno "¿Desea compactar el menú?" 7 45
}


#
# Tranforma la notación CIDR en IP y MÁSCARA.
# $1: La red en formato CIDR
#
cidr2mask() {
   local python=`which python3 || which python`
   $python -c 'from ipaddress import IPv4Network as network; n=network("'$1'"); print("{!s} {!s}".format(n, n.netmask))'
}


#
# Genera un rango de ips dinámicas
# $1: La red.
# $2: IPs fuera del rango al principio de la red.
# $3: IPs fuera del rango al final de la red.
#
get_range() {
   local python=`which python3 || which python`
   local net="$1" c="${2:-0}" f="${3:-0}"
   $python -c 'from ipaddress import IPv4Interface as ip
x=ip("'"$1"'")
print("{!s}".format((x + 1 + '"$c"').ip), end=" ")
print("{!s}".format(x.network.broadcast_address - 1 - '"$f"'))'
}


# Obtiene el servidor DNS actualmente en uso.
get_dnsserver() {
   local server
   server=`host -v -W 3 www.google.es 2>/dev/null | sed -r '/^Received/!d; s:.*\s([^\S]+)+#.*:\1:; q'` || return 1
   [ "${server%%.*}" != "127" ] || return 1
   echo "$server"
}


#
# Crea la configuración del servidor ISC.
# $1: Tipo de servicio (0-3)
#
configure_isc() {
   local time=28800
   local type="$1"

   is_present "$dhcp" "dhcpd" || return 1

   mkdir -p "$root$confdir/configs/isc"
   case "$type" in
      0|1)  # Proporciona configuraciones de red.
         exec 3>&1 1>"$root$confdir/configs/isc/dhcpd.conf"
         echo "# /etc/dhcp/dhcpd.conf

authoritative;
ddns-update-style none;
default-lease-time $time;
max-lease-time $time;

include \"/etc/dhcp/pxe.conf\";
"

         echo "$networks" | while read line; do
            eval "$(parse_netinfo "$line")"
            [ -n "$ip" ] || continue
            mask=$(cidr2mask "$net") ; mask=${mask#* }
            echo "subnet ${net%/*} netmask $mask {
   range $(get_range "$net" 10);

   option domain-name-servers $ip;
   option domain-name \"$aula.$DOMAIN1\";
   option routers $ip;
}
"
         done
         exec 1>&3 3>&-
         configure_pxe_isc "$type";;
      *) ;;  # No puede darse el caso (no hace nada)
   esac
}

#
# Crea la configuración del servidor ISC relativa al PXE
# $1: Tipo de servicio (0-3)
#
configure_pxe_isc() {
   local type="$1"

   exec 3>&1 1>"$root$confdir/configs/isc/pxe.conf"

   echo "# /etc/dhcp/pxe.conf
# Disminuímos el tiempo de concesion de las direcciones IP
# cuándo esta ha sido requierida por pxelinux.
class \"PXEClient\" {
   match if substring(option vendor-class-identifier, 0, 9) = \"PXEClient\";
   default-lease-time 900;
}
"
   case "$type" in
      1) echo "option vendor-class-identifier \"PXEClient\";";;
      0) echo "next-server $httpname;

option arch code 93 = unsigned integer 16;
option pxe-pathprefix code 210 = text;
if option arch = 00:06 {
   filename \"efi32/syslinux.efi\";
   option pxe-pathprefix \"http://$httpname/boot/efi32/\";
} elsif option arch = 00:07 or option arch = 00:09 {
   filename \"efi64/syslinux.efi\";
   option pxe-pathprefix \"http://$httpname/boot/efi64/\";
} else {
   filename \"bios/lpxelinux.0\";
   option pxe-pathprefix \"http://$httpname/boot/bios/\";
}


if exists dhcp-parameter-request-list {
   option dhcp-parameter-request-list = concat(option dhcp-parameter-request-list, d2);
}";;
      *) ;;
   esac
   exec 1>&3 3>&-
}


# Crea la configuración del servidor udhcpd.
# $1: Tipo de servicio (0-3)
configure_udhcpd() {
   local type="$1"

   is_present "$dhcp" "udhcpd" || return 1

   exec 3>&1 1>"$root$confdir/configs/udhcpd.conf"
   echo "#TODO: Sin soporte aún"
   exec 1>&3 3>&-
}


#
# Crea la configuración de DNSMasq
# $1: Tipo de servicio (0-3)
#
configure_dnsmasq() {
   local type=$1

   is_present "$dhcp" "dnsmasq" || return 1

   mkdir -p "$root$confdir/configs/dnsmasq"
   exec 3>&1 1>"$root$confdir/configs/dnsmasq/dhcp.conf"
   case "$type" in
      0)  # Debe proporcionar direcciones IP
         echo "dhcp-vendorclass=set:pxe,PXEClient"
         echo
         echo "$networks" | while read line; do
            eval "$(parse_netinfo "$line")"
            [ -n "$ip" ] || continue
            range=$(get_range "$net" 10 | sed 'y: :,:')
            echo "domain=${aula}.$DOMAIN1,$net
dhcp-range=tag:!pxe,$range,8h
dhcp-range=tag:pxe,$range,15m"
            echo
         done
         ;;
      1|2)  # Debe ponerse a escuchar en un puerto alternativo
         [ $type -eq 1 ] && echo "dhcp-alternate-port=0" && echo
         echo "$networks" | while read line; do
            eval "`parse_netinfo "$line"`"
            echo "dhcp-range=${net%/*},proxy"
         done

         echo "
dhcp-no-override
dhcp-option=vendor:PXEClient,6,2b"
         ;;
      *) error "Este mensaje no debería nunca aparecer"
         exit 1
         ;;
   esac
   exec 1>&3 3>&-

   configure_pxe_dnsmasq "$type"
   configure_tftp_dnsmasq
   configure_dns_dnsmasq
}


#
# Configuración PXE de DNSmasq
# $1: Tipo de servicio (0-3)
#
configure_pxe_dnsmasq() {
   local type="$1"
   exec 3>&1 1>"$root$confdir/configs/dnsmasq/pxe.conf"

   echo "# /etc/dnsmasq.d/pxe.conf

dhcp-match=bios,93,0
dhcp-match=efi32,93,6
dhcp-match=efi64,93,7
dhcp-match=efi64,93,9i

# La configuración de syslinux se obtiene por HTTP
dhcp-option=tag:bios,encap:43,vendor:PXEClient,210,http://$httpname/boot/bios/
dhcp-option=tag:efi32,encap:43,vendor:PXEClient,210,http://$httpname/boot/efi32/
dhcp-option=tag:efi64,encap:43,vendor:PXEClient,210,http://$httpname/boot/efi64/"
   case $type in
      0)  # No hay servicio PXE propiamente: se usan las opciones del DHCP
         echo "
dhcp-boot=tag:bios,bios/lpxelinux.0
dhcp-boot=tag:efi32,efi32/syslinux.efi
dhcp-boot=tag:efi64,efi64/syslinux.efi";;
      1|2)  # Servicio PXE
         echo "
pxe-service=x86PC,"Servicio de clonaciones",bios/lpxelinux.0

# En UEFI, forzamos a syslinux a enviar el menú PXE y,
# solidariamente, la opción 43. Ver notas a la ver. 2.76 en:
# http://www.thekelleys.org.uk/dnsmasq/CHANGELOG
pxe-prompt="Leyenda invisible",0
pxe-service=IA32_EFI,"Servicio de clonaciones",efi32/syslinux.efi
pxe-service=IA32_EFI,"Servicio de clonaciones",efi32/syslinux.efi
pxe-service=BC_EFI,"Servicio de clonaciones",efi64/syslinux.efi
pxe-service=BC_EFI,"Servicio de clonaciones",efi64/syslinux.efi
pxe-service=x86-64_EFI,"Servicio de clonaciones",efi64/syslinux.efi
pxe-service=x86-64_EFI,"Servicio de clonaciones",efi64/syslinux.efi";;
   esac
   exec 1>&3 3>&-
}

#
# Configura dnsmasq como servidor TFTP
#
configure_tftp_dnsmasq() {
   echo "# /etc/dnsmasq.d/tftp.conf
enable-tftp
tftp-root=$tftpdir" > "$root$confdir/configs/dnsmasq/tftp.conf"
}


#
# Configura dnsmasq para que actúe de servidor DNS
#
configure_dns_dnsmasq() {
   local dns=`get_dnsserver`

   # Si se proprociona una IP, no es configurar el dns.
   es_ip "$httpname" && return 1

   dns=${dns:-$DNSSERVER}

   echo "# /etc/dnsmasq.d/dns.conf

no-resolv
server=$dns

localise-queries
addn-hosts=$root$confdir/hosts.conf
" > "$root$confdir/configs/dnsmasq/dns.conf"

   echo "$networks" | while read line; do
      eval "`parse_netinfo "$line"`"
      [ -n "$ip" ] || continue
      printf "%-15s %s %s\n" "$ip" "$httpname" "$httpname.$aula.$DOMAIN1"
   done > "$root$confdir/hosts.conf"
}


#
# Configura nginx
# $1: Plantilla de configuración
#
configure_nginx() {
   local IFS iface ip net aula desc names="$httpname"
   IFS='
'
   if ! es_ip "$names"; then
      for line in $networks; do
         eval "`parse_netinfo "$line"`"
         [ -n "$iface" ] || continue
         names="$names $httpname.$aula.$DOMAIN1"
      done
   fi
   sed -r '/server_name _/s:_;:'"$names"';:; s:alias /srv/tftp:alias '"$tftpdir"':; s:alias /appdir;:alias '"$appdir"';:; s|unix:/socket|unix:'"$PHP_SOCKET|" "$1"
}


# Crea la entrada de sudo para que el grupo de
# clonaciones sea capaz de arrancar drbl-ocs
configure_sudo() {
   echo "# /etc/sudoers.d/clonaton

%$group ALL = (root) NOPASSWD: /sbin/poweroff"
}


#
# Configura NFS
#
configure_exports() {
   local perms="(ro,sync,no_subtree_check)"

   echo -n "$imgdir      "
   echo "$networks" | while read line; do
      eval "`parse_netinfo "$line"`"
      [ -n "$iface" ] || continue
      echo -n "$net$perms  "
   done
   echo
}


# Convierte 0/1 en true/false
# $1: 0/1
truefalse() {
   [ $1 -eq 1 ] && echo "true" || echo "false"
}


#
# Crea el fichero que contiene la configuración generada
#
create_conffile() {
   echo "# Configuración de clonatón
dhcp = $dhcp
dhcp_type = $dhcp_type
tftp = $tftp
group = $group
compact = $compact
appdir = $appdir
imgdir = $imgdir
sysdir = $sysdir
sysdir32 = $sysdir32
sysdir64 = $sysdir64
nbpfile = $nbpfile
nbpfile32 = $nbpfile32
nbpfile64 = $nbpfile64
tftpdir = $tftpdir
drbldir = $drbldir
menu = $menu
visible = $visible
shiftkey = $shiftkey
httpname = $httpname
timeout = $timeout"
}


#
# Modifica la configuración de la aplicación web (config.php)
#
patch_appconfig() {
   local config="etc/config.php"
   local mconfig="modules/clonezilla/config.php"

   sed -r '/COMPACT/s:, \w+:, '$(truefalse $compact)':;
            /VERBOSE/s:, \w+:, '$(truefalse $visible)':;
            /SHIFTKEY/s:, \w+:, '$(truefalse $shiftkey)':;
            /TFTPDIR/s:, "[^"]+:, "'"$tftpdir"'/bios:;
            /UI/s:, "[^"]+:, "'$menu'.c32:;
            /TIMEOUT/s:, \d+:, '$timeout':;' "$installerdir/app/$config" > "$root$appdir/$config"

   sed -r '/IMGDIR"/s:, "[^"]+:, "'"$imgdir:" "$installerdir/app/$mconfig" > "$root$appdir/$mconfig"
}


#
# Prepara los ficheros de slitaz.
#
prepare_slitaz() {
   local tmpdir="$1"
   local target="$root$tftpdir/ssoo/slitaz"

   mkdir -p "$target"

   if ! wget --timeout=30 -q --spider "$SLITAZ_URL"; then
      error "Imposible descargar SliTaZ"
      return 1
   fi

   wget --tries=5 --timeout 30 -qcO /tmp/slitaz.iso --show-progress --progress=dot "$SLITAZ_URL" 2>&1 | \
      stdbuf -o0 grep -oP '[0-9]+(?=%)' | whiptail --gauge "Descargando SliTaZ..." 7 50 0
   mount -o ro,loop /tmp/slitaz.iso "$tmpdir"
   cp -p "$tmpdir"/boot/bzImage "$tmpdir"/boot/rootfs.gz "$target"
   umount "$tmpdir"
   mv "$target/rootfs.gz" "$target/rootfs-core.gz"
   ln -s rootfs-core.gz "$target/rootfs.gz" 
   cp -a "$installerdir"/files/rootfs-local.gz "$target"
}


#
# Prepara los ficheros de clonezilla.
#
prepare_clonezilla() {
   local tmpdir="$1"
   local target="$root$tftpdir/ssoo/clonezilla"

   mkdir -p "$target"

   if ! wget --timeout=30 -q --spider "$CLONEZILLA_URL"; then
      error "Imposible descargar Clonezilla"
      return 1
   fi

   wget --tries=5 --timeout 30 -qcO /tmp/clonezilla.iso --show-progress --progress=dot "$CLONEZILLA_URL" 2>&1 | \
      stdbuf -o0 grep -oP '[0-9]+(?=%)' | whiptail --gauge "Descargando clonezilla..." 7 50 0
   mount -o ro,loop /tmp/clonezilla.iso "$tmpdir"
   cp -p "$tmpdir"/live/vmlinuz "$tmpdir"/live/initrd.img "$tmpdir"/live/filesystem.squashfs "$target"
   umount "$tmpdir"
}


#
# Obtiene memtest.bin
#
prepare_memtest() {
   local tmpdir="$1"
   local target="$root$tftpdir/ssoo"

   mkdir -p "$target"

   if ! wget --timeout=30 -q --spider "$MEMTEST_URL"; then
      error "Imposible descargar memtest"
      return 1
   fi
   { wget --tries=5 --timeout 30 -qcO - --show-progress --progress=dot "$MEMTEST_URL" | \
     gunzip > "$target/memtest.bin"
   } 2>&1 | stdbuf -o0 grep -oP '[0-9]+(?=%)' | dialog --gauge "Descargando memtest..." 7 50 0
}


#
# Instala los ficheros modules.alias y pci.ids
# para que hdt sea capaz de utilizarlos.
#
prepare_hdt() {
   local pciids dir target="$root$tftpdir/ssoo/hdt"

   mkdir -p "$target"

   for dir in /usr/share/misc /usr/share/hwdata /var/lib/pciutils; do
      [ -f "$dir/pci.ids" ] || continue
      pciids="$dir/pci.ids" && break
   done

   if [ -n "$pciids" ]; then
      gzip -9c "$pciids" > "$target/pci.ids"
   else
      ln -sf /dev/null "$target/pci.ids"
      edialog "No se encuentra pci.ids, por lo que hdt estará desactivado. Revise si lo tiene o descárguelo de http://pci-ids.ucw.cz/ e inclúyalo en $target." 9 55
   fi

   gzip -9c /lib/modules/`uname -r`/modules.alias > "$target/modules.ali"
}


# $1: Arquitectura
prepare_syslinux() {
   local arch="$1" nbp sdir nbp ldlinux

   case "$arch" in
      bios)
         sdir="$sysdir"
         nbp="$nbpfile"
         ldlinux="ldlinux.c32"
         nbpname="lpxelinux.0"
         ;;
      efi32)
         sdir="$sysdir32"
         nbp="$nbpfile32"
         ldlinux="ldlinux.e32"
         nbpname="syslinux.efi"
         ;;
      efi64)
         sdir="$sysdir64"
         nbp="$nbpfile64"
         ldlinux="ldlinux.e64"
         nbpname="syslinux.efi"
         ;;
   esac

   if [ ! -d "$sdir" ]; then
      edialog --msgbox "No se encuentra syslinux-$arch en el sistema, por lo que no puede poblarse convenientemente $tftpdir/$arch. Se crearán enlaces simbólicos a /dev/null para que sepa cuáles son los módulos que debe procurarse." 10 55
   fi

   if [ ! -f "`readlink -f "$root$tftpdir/$arch/$nbpname"`" ]; then
      cd "$root$tftpdir/$arch"
      for mod in cmd.c32 hdt.c32 libcom32.c32 libgpl.c32 libmenu.c32 $ldlinux \
                 libutil.c32 menu.c32 poweroff.c32 reboot.c32 vesamenu.c32; do
         if [ -d "$sdir" ]; then
            ln -sf "$sdir/$mod" syslinux
         else
            ln -sf /dev/null syslinux/$mod
         fi
      done
   fi


   if [ ! -e "$nbp" ]; then
      edialog --msgbox "No se encuentra el NBP de $arch en el sistema, por lo que no puede poblarse convenientemente $tftpdir/$arch. Se crearán enlaces simbólicos a /dev/null para que sepa cuáles son los módulos que debe procurarse." 10 55
   fi

   if [ ! -f "`readlink -f "$root$tftpdir/$arch/$nbpname"`" ]; then
      cd "$root$tftpdir/$arch"
      if [ -n "$nbp" ]; then
         ln -sf "$nbp"
      else
         ln -sf /dev/null "$nbpname"
      fi
   fi
}


#
# Argumentos
#
compact=
appdir=
imgdir=
sysdir=
sysdir32=
sysdir64=
expert=
force=
tftpdir=
menu=
visible=
shiftkey=
httpname=
timeout=
no_ssoo=
root=
no_networks=

while [ $# -gt 0 ]; do
   case $1 in
      -c|--compact) 
         compact=1
         shift;;
      -d|--appdir)
         appdir=$2
         shift 2;;
      -e|--expert)
         expert=1
         shift;;
      -f|--tftpdir)
         tftpdir=$2
         shift 2;;
      -F|--force)
         force=1
         shift;;
      -G|--graphic)
         menu=vesamenu
         shift;;
      -g|--group)
         group=$2
         shift;;
      -h|--help)
         help
         exit 0;;
      -H|--hide-items)
         visible=0
         shift;;
      -i|--imgdir)
         imgdir=$2
         shift 2;;
      -l|--loose)
         compact=0
         shift;;
      -m|--show-menu)
         shiftkey=0
         shift;;
      -M|--sysdir)
         sysdir=$2
         shift 2;;
      -M32|--sysdir32)
         sysdir32=$2
         shift 2;;
      -M64|--sysdir64)
         sysdir64=$2
         shift 2;;
      -N|--no-ssoo)
         no_ssoo=1
         shift;;
      -n|--httpname)
         httpname=$2
         shift 2;;
      -P|--nbpfile)
         nbpfile=$2
         shift 2;;
      -P32|--nbpfile32)
         nbpfile32=$2
         shift 2;;
      -P64|--nbpfile64)
         nbpfile64=$2
         shift 2;;
      -r|--root)
         root=$2
         shift 2;;
      -s|--shiftkey)
         shiftkey=1
         shift;;
      -S|--show-items)
         visible=1
         shift;;
      -t|--timeout)
         timeout=$2
         shift 2;;
      -T|--textmenu)
         menu=menu
         shift;;
      -w|--no-networks)
         no_networks=1
         shift;;
      -*) eerror 2 "$1: Opción inválida. Pruebe --help para ayuda";;
      *) eerror 2 "No se admiten argumentos. Pruebe --help para ayuda";; 
   esac
done

# Comprobación de valores.
[ -n "$httpname" ] && { es_nombre_valido "$httpname" || eerror 2 "$httpname: Nombre de grupo inválido."; }
[ -n "$group" ] && { es_grupo_valido "$group" || eerror 2 "$group: Nombre de grupo inválido."; }
[ -n "$timeout" ] && { es_numero_entero "$timeout" || eerror 1 "$timeout: Número de segundos inválido."; }
if es_root_valida "$root"; then
   [ -n "$root" ] && root=`readlink -f "$root"`
else
   eerror 1 "$root: El directorio escogido como raíz no existe"
fi

# ¿Hay que instalar?
[ -n "$force" ] || ! is_installed && install=1


if [ -n "$install" ]; then
   dhcp=$(get_pxe_type)
   dhcp_type=$?
   [ $dhcp_type -eq 255 ] && exit 255

   if [ -z "$dhcp" ]; then
      dhcp="dnsmasq"
      get_dnsmasq_role "No se han detectado ningún servidor DHCP instalado. En consecuencia, se presupondrá que instalará DNSmasq. Escoja cómo actuará"
      dhcp_type=$?
   fi

   # Si no está instalado DNSmasq, debe haber un servidor TFTP independiente
   if ! is_present "$dhcp" "dnsmasq"; then
      tftp=$(get_tftp_server)
   else
      tftp="dnsmasq"
   fi
else
   dhcp=${old_dhcp}
   dhcp_type=${old_dhcp_type}
   tftp=${old_tftp}
fi

sysdir=$(check_syslinux "bios" "$sysdir:-$old_sysdir")
sysdir32=$(check_syslinux "efi32" "$sysdir32:-$old_sysdir32")
sysdir64=$(check_syslinux "efi64" "$sysdir64:-$old_sysdir64")

nbpfile=$(check_nbp "bios" ${nbpfile:-$old_nbpfile})
nbpfile32=$(check_nbp "efi32" ${nbpfile32:-$old_nbpfile32})
nbpfile64=$(check_nbp "efi64" ${nbpfile64:-$old_nbpfile64})


while [ -z "$httpname" ]; do
   sugerencia="${old_httpname:-$HTTPNAME}"
   httpname=$(pregunta_nombre "$sugerencia")
   case $? in
      0) break;;
      1) error "$httpname: Nombre inválido" 
         old_httpname=$httpname
         httpname=;;
      2) cancel "¿Desea abandonar la instalación?";;
   esac
done


if [ -n "$expert" ] && [ -n "$install" ]; then
   sugerencia="${old_appdir:-$APPDIR}"
   while [ -z "$appdir" ]; do
      appdir=$(pregunta_appdir "$sugerencia")
      case $? in
         0) break;;
         1) error "$appdir: Directorio inválido" 
            sugerencia=$appdir
            appdir=;;
         2) cancel "¿Desea abandonar la instalación?";;
      esac
   done
else
   appdir=${old_appdir:-$APPDIR}
fi


sugerencia="${old_tftpdir:-$TFTPDIR}"
while [ -z "$tftpdir" ]; do
   tftpdir=$(pregunta_tftpdir "$sugerencia" "$tftp")
   case $? in
      0) break;;
      1) error "$tftpdir: Directorio inválido" 
         sugerencia=$tftpdir
         tftpdir=;;
      2) cancel "¿Desea abandonar la instalación?";;
   esac
done


sugerencia="${old_imgdir:-$IMGDIR}"
while [ -z "$imgdir" ]; do
   imgdir=$(pregunta_imgdir "$sugerencia")
   case $? in
      0) break;;
      1) error "$imgdir: Directorio inválido" 
         sugerencia=$imgdir
         imgdir=;;
      2) cancel "¿Desea abandonar la instalación?";;
   esac
done


while [ -z "$no_networks" ]; do
   networks=`pregunta_redes "$appdir/etc/networks"`
   if [ $? -eq 0 ]; then
      break
   else
      cancel "¿Desea abandonar la instalación?"
   fi
done

while true; do
   DOMAIN1=$(pregunta_dominio "$DOMAIN1")
   case $? in
      0) break;;
      1) error "$DOMAIN1: Dominio inválido";;
      2) cancel "¿Desea abandonar la instalación?";;
   esac
done


if [ -n "$expert" ]; then
   while [ -z "$group" ]; do
      sugerencia="${old_group:-$APPGROUP}"
      group=`pregunta_grupo $sugerencia` && break
      case $? in
         0) break;;
         1) error "$group: Grupo inválido" 
            old_group=$group
            group=;;
         2) cancel "¿Desea abandonar la instalación?";;
      esac
   done
   edialog --msgbox "¡Atención! Si quiere subir imágenes al servidor, necesitará un usuario que pertenezca al grupo $group." 9 55

   while [ -z "$menu" ]; do
      menu=`pregunta_menu $old_menu` && break
      cancel "¿Desea abandonar la instalación?"
   done

   while [ -z "$shiftkey" ]; do
      pregunta_shiftkey $old_shiftkey
      shiftkey=$?
      if [ $shiftkey -eq 255 ]; then
         cancel "¿Desea abandonar la instalación?"
         shiftkey=
      else
         break
      fi
   done

   sugerencia=100
   [ "$shiftkey" = "1" ] && sugerencia=0
   while [ -z "$timeout" ]; do
      timeout=`pregunta_temp $sugerencia` && break
      cancel "¿Desea abandonar la instalación?"
   done

   while [ -z "$visible" ]; do
      pregunta_visible $old_visible
      visible=$?
      if [ $visible -eq 255 ]; then
         cancel "¿Desea abandonar la instalación?"
         visible=
      else
         break
      fi
   done

   while [ -z "$compact" ]; do
      pregunta_compact $old_compact
      compact=$?
      if [ $compact -eq 255 ]; then
         cancel "¿Desea abandonar la instalación?"
         compact=
      else
         # Convertir 0 en 1 y 1 en 0.
         compact=$(((compact+1)%2))
         break
      fi
   done
else
   [ -z "$group" ] && group=${old_group:-$APPGROUP}
   edialog --msgbox "¡ATENCIÓN! Sólo los usuarios que pertenezcan al grupo $group tendrán permisos para subir imágenes a este servidor. Recuerdo asegurarse de añadir al menos un usuario a este grupo" 10 55
   [ -z "$menu" ] && menu=${old_menu:-vesamenu}
   [ -z "$shiftkey" ] && shiftkey=${old_shiftkey:-1}
   if [ -z "$timeout"]; then
      if [ "$shiftkey" = "1" ]; then
         timeout=${old_timeout:-0}
      else
         timeout=${old_timeout:-100}
      fi
   fi
   [ -z "$visible" ] && visible=${old_visible:-1}
   [ -z "$compact" ] && compact=${old_compact:-1}
fi

# Eliminamos las barras finales de las rutas, si existen.
appdir=${appdir%/}
tftpdir=${tftpdir%/}
imgdir=${imgdir%/}
root=${root%/}

drbldir="$appdir/modules/clonezilla/drbl"
# Fin de la entrada de datos

#
# Configuración e instalación de ficheros
#

installerdir="$(readlink -f `dirname $0`)/.."


# Creamos el grupo en caso de que no exista.
getent group "$group" >/dev/null || groupadd -r "$group"


# Copiamos los ficheros de configuración
if [ -d "$old_appdir" ]; then
   tmpdir=`mktemp -d`
   # Copiamos los ficheros de configuracion:
   mv "$old_appdir/etc/hosts" "$old_appdir/etc/config.php" "$tmpdir"
   mv "$old_appdir/modules/clonezilla/config.php" "$tmpdir/clonezilla-config.php"
   rm -rf "$old_appdir"
fi

# Copiamos la aplicación
mkdir -p "`dirname "$root$appdir"`"
cp -a "$installerdir"/app "$root$appdir"

# Y sobre ella, los ficheros de configuración
if [ -d "$tmpdir" ]; then
   mv -f "$root$appdir/etc/config.php" "$root$appdir/etc/config.php.dpkg-old"
   mv -f "$root$appdir/modules/clonezilla/config.php" "$root$appdir/modules/clonezilla/config.php.dpkg-old"
   mv -f "$tmpdir/hosts" "$root$appdir/etc"
   mv "$tmpdir/config.php" "$root$appdir/etc"
   mv "$tmpdir/clonezilla-config.php" "$root$appdir/modules/clonezilla/config.php"
   rmdir "$tmpdir"
fi

chown "$WWWUSER" "$root$appdir"/cache
chgrp "$group" "$root$appdir"/etc/hosts
chmod g+w "$root$appdir"/etc/hosts
echo -n "$networks" | awk -F, -v OFS=, '{print $4, $3, $1, $5}' > "$root$appdir"/etc/networks
patch_appconfig


touch "$LOGFILE"
chgrp clonaton "$LOGFILE"
chmod g+w "$LOGFILE"


# Directorio de imágenes
if [ "$old_imgdir" != "$root$imgdir" ] && [ -d "$old_imgdir" ]; then
   mkdir -p "`dirname "$root$imgdir"`"
   mv "$old_imgdir" "$root$imgdir"
elif [ ! -d "$root$imgdir" ]; then
   mkdir -p "$root$imgdir"
fi
chgrp "$group" "$root$imgdir"
chmod 2775 "$root$imgdir"


# Borramos la configuración antigua.
confdir="`dirname "$CONFFILE"`"
mkdir -p "$root$confdir/configs"


# DHCP
if [ -n "$force" ] || [ "$dhcp" != "$old_dhcp" ] || [ "$dhcp_type" != "$old_dhcp_type" ] || [ "$tftp" != "$old_tftp" ]; then
   echo -n "Espere mientras se configura DHCP/PXE... "

   rm -rf "$root$confdir/configs/isc" "$root$confdir/configs/dnsmasq" "$root$confdir/configs/udhcpd.conf" 

   configure_isc $dhcp_type
   configure_udhcpd $dhcp_type
   configure_dnsmasq $dhcp_type

   echo "Hecho"
fi

if [ $? -ne  0 ]; then
   leyenda="Puesto que no usa DNSmasq deberá configurar por su cuenta un servidor TFTP para que sirva los ficheros dentro de $TFTPDIR"
   if es_ip "$httpname"; then
      leyenda="$leyenda."
   else
      leyenda="$leyenda, y un DNS para que resuelva $httpname a todas las IP del servidor de clonaciones."
   fi
   dialog --msgbox "$leyenda" 10 60
fi


# Crear entrada para que se pueda ejecutar drbl-ocs con sudo.
configure_sudo > "$root$confdir/configs/sudo.clonaton"


# NGINX
configure_nginx "$installerdir/files/nginx.pxe" > "$root$confdir/configs/site-pxe"


# NFS
configure_exports > "$root$confdir/configs/exports"


# Generacón de /etc/clonaton/clonaton.conf
create_conffile > "$root$CONFFILE"


# Si ya se instaló en otra ubicación el directorio TFTP, se mueve.
if [ "$old_tftpdir" != "$root$tftpdir" ]; then
   mkdir -p  "$root$tftpdir"
   for dir in bios efi32 efi64 ssoo; do
      [ -d "$old_tftpdir/$dir" ] || continue
      mv "$old_tftpdir/$dir" "$root$tftpdir"
   done
   if [ -d "$old_tftpdir" ] && [ -z "`ls -A "$old_tftpdir"`" ]; then
      dialog --yesno "El antiguo directorio $old_tftpdir ha quedado vacío, ¿desea borrarlo?" 8 55 && rmdir "$old_tftpdir"
   fi
fi

# Crea el contenido dentro de /srv/ftp (excepto ssoo)
mkdir -p "$root$tftpdir/bios/syslinux" \
         "$root$tftpdir/efi32/syslinux" \
         "$root$tftpdir/efi64/syslinux"

prepare_syslinux bios
prepare_syslinux efi32
prepare_syslinux efi64

if [ -z "$no_ssoo" ]; then
   # Crea el contenido dentro de /srv/ftp/ssoo
   tmpdir=$(mktemp -d)
   trap "rm -rf /tmp/slitaz.iso /tmp/clonezilla.iso /tmp/memtest.iso $tmpdir" EXIT INT TERM
   [ -d "$root$tftpdir/ssoo/hdt" ] || prepare_hdt
   [ -f "$root$tftpdir/ssoo/memtest.bin" ] || prepare_memtest "$tmpdir"
   [ -d "$root$tftpdir/ssoo/slitaz" ] || prepare_slitaz "$tmpdir"
   [ -d "$root$tftpdir/ssoo/clonezilla" ] || prepare_clonezilla "$tmpdir"
fi

# TODO: Cambiará por el parcheo de clonezilla
cp -a "$installerdir"/drbl  "$root$drbldir"
