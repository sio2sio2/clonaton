<?php
require(__DIR__."/../../utils.php");
header("Content-Type: text/plain");

/**
 * Devuelve la lista de directorios que contienen imágenes
 *
 * @return string
 */
function lista_directorios() {
   return implode("\n", array_map("basename", glob(clonezilla\IMGDIR."/*")));
}

/**
 * Averigua si hay que apagar el servidor al término de la creación.
 */
function server_off() {
   if(clonezilla\SERVER_OFF !== null) return clonezilla\SERVER_OFF;
   $conf = parse_conf();
   return $conf['dhcp_type'] == 2;
}

?>
#!/bin/sh
#
# Hace algunas preguntas necesarias para crear la imagen.
# El script corre en el cliente, pero requiere conocer
# ciertos datos existentes en el servidor, por lo que
# el valor de las variables iniciales lo generamos
# dinámicamente.

# Si se ejecuta con parámentros es porque
# lo invoca ssh (SSH_ASKPASS).
if [ $# -gt 0 ]; then
   cat
   exit 0
fi

nfsserver=<?php echo $_SERVER['HTTP_HOST']."\n"; ?>
aula=<?php echo $params->get('room')."\n"; ?>
mac=<?php echo $params->get('mac')."\n"; ?>
tipo=<?php echo "{$params['type']}\n"; ?>
imgdir=<?php echo '"'.clonezilla\IMGDIR."\"\n"; ?>
server_off=<?php echo (server_off()?"1":"0")."\n"; ?>
ask_server_off=<?php echo (clonezilla\SERVER_OFF === null)."\n" ?>
# Hasta que no se complete la imagen, la descripción
# tendrá el sufijo ".tmp". Así sabremos si la creación
# de la imagen se completó.
descfile="<?php echo clonezilla\DESCIMG; ?>".tmp

title="Pre-Clonezilla: Creación de imagen"

<?php echo file_get_contents(__DIR__."/../lib/dialog.sh"); ?>

<?php echo file_get_contents(__DIR__."/../lib/utils.sh"); ?>

# Crea una sugerencia para el nombre
# de la imagen de la forma "tipo_AñoMes".
sugerir_nombre() {
   ocal nombre
   while i=""; do
      nombre=${tipo:-desc.}_$(date +'%b%Y')${i:+_$i}
      [ -f "$imgdir/$nombre" ] || break
      i=$((i+1))
   done
   echo $nombre
}


# Realiza una gestión en el servidor
# $1: usuario
# $2: contraseña
# $3...: Orden en el servidor
rcommand() {
   local usuario="$1" password="$2"
   shift 2
   [ -n "$DISPLAY" ] || export DISPLAY=dummy:0
   echo "$password" | SSH_ASKPASS=$0 setsid ssh -o StrictHostKeyChecking=no "$usuario"@$nfsserver "$*"
}

# Comprueba si el tipo de máquina ya existe.
existe_tipo() {
   local lista_tipos="<?php echo lista_tipos(); ?>"
   echo "$lista_tipos" | egrep -q "^$1="
}


# Comprueba si el nombre para el tipo es válido.
es_tipo_valido() {
   echo "$1" | grep -Eq '^[-[:alnum:]_.#]+$' 
}


# Comprueba si el nombre de imagen ya existe.
existe_nombre() {
   local lista_nombres="<?php echo lista_imagenes(); ?>"
   echo "$lista_nombres" | grep -Eq "^$1="
}


# Comprueba si el nombre de usuario es correcto
es_usuario_valido() {
   return 0
}

# Comprueba si el nombre de imagen es válido
es_nombre_valido() {
   es_tipo_valido "$1"
}


# Comprueba si el aula proporcionada existe.
existe_aula() {
   local lista_aulas="<?php echo lista_aulas(); ?>"
   echo "$lista_aulas" | egrep -q "^$1="
}


# Pregunta el tipo de ordenador.
# $1: Nombre sugerido.
#
# return:
#    - 0, éxito; 1, error; 2: cancelación.
#    - Imprime el nombre del usuario
pregunta_tipo() {
   local resp
   resp=$(dialog --inputbox "Se ha detectado un nuevo tipo de ordenador. Introduzca su nombre (o déjelo vacío si no quiere crear ningún tipo)" 10 50 "$1") || return 2

   echo $resp
   [ -n "$resp" ]
}


pregunta_desc() {
   local resp
   resp=$(dialog --inputbox "Escriba una breve descripción para el tipo" 8 50 "$1") || return 2
   echo $resp
}


# Pregunta si el ordenador es reciente
# para fijar el parámetro de localboot a 0 o -1.
#
# Devuelve 0 (no reciente) o "" (reciente).
pregunta_reciente() {
   local resp
   dialog --yesno "¿Es el ordenador relativamente reciente?" 7 45

   case $? in
      0) ;;
      1) echo 0;;
      255) return 2;;
   esac

}

# Pregunta cuál es el usuario SSH para acceso al servidor
# $1: Nombre sugerido.
#
# return:
#    - 0 si se completo la introducción; 1 si se dejó vacío; y 2 si se canceló.
#    - Imprime el nombre del usuario
pregunta_usuario() {
   local reso
   resp=$(dialog --inputbox "Usuario con acceso SSH" 8 35 "$1") || return 2

   echo $resp
   [ -n "$resp" ]
}


pregunta_password() {
   local resp
   resp=$(dialog --passwordbox "Contraseña" 8 35 "$1") || return 2
   echo "$resp"
}


pregunta_nombre() {
   local resp
   resp=$(dialog --inputbox "Nombre la imagen con una única palabra significativa (después se le pedirá una descripción):" 9 45 "$1") || return 2

   echo $resp
   [ -n "$resp" ]
}


pregunta_descnombre() {
   local resp
   resp=$(dialog --inputbox "Escriba una breve descripción para la imagen" 8 50 "Imagen $1") || return 2
   echo $resp
}


# Establece el nombre definitivo del directorio
# done se almacenará la imagen.
# $1: El nombre al que se le irá añadiendo _2, _3, etc...
set_dirname() {
   local dirs="<?php echo lista_directorios(); ?>"
   local nombre="$1" i=1

   while true; do
      echo "$dirs" | grep -q '^'"$1"'$' || break
      i=$((i+1))
      nombre=$1_$i
   done

   echo $imgdir/$nombre
}


###
# Código principal
###

# Obtenemos el tipo en caso de que sea desconocido.
if [ -z "$tipo" ]; then
   while true; do
      tipo=$(pregunta_tipo "$tipo")

      case $? in
         0) ;;
         1) dialog --yesno --defaultno "¿Desea dejar sin definir el tipo?" 7 45 && break 
            continue
            ;;
         2) cancel "¿Desea cancelar la creación?"
            continue
            ;;
      esac

      ! es_tipo_valido "$tipo" && error "Tipo inválido: escriba una palabra" && continue
      existe_tipo "$tipo" && ! dialog --defaultno --yesno "El nombre ya está registrado para otro tipo. ¿Desea usarlo de todos modos?" 8 55 && continue
      desctipo=$(pregunta_desc "Ordenadores $tipo") || { cancel "¿Desea cancelar la creación?" && continue; }
      desctipo="${desctipo:-Ordenadores $tipo}"
      reciente=$(pregunta_reciente) || { cancel "¿Desea cancelar la creación?" && continue; }
      break
   done
fi


while true; do
   # Obtenemos el usuario de acceso
   while true; do
      usuario=$(pregunta_usuario "$usuario")

      case $? in
         0) es_usuario_valido "$resp" && break
            error "'$resp': Usuario inválido"
            ;;
         1) error "Se requiere un nombre de usuario"
            continue
            ;;
         2) cancel "¿Desea cancelar la creación?"
            continue
            ;;
      esac

   done

   # y su contraseña
   while [ -z "$password" ]; do
      password=$(pregunta_password) || cancel "¿Desea cancelar la creación?"
   done

   # Si hay descripción del tipo, es que el tipo es nuevo y hay que inscribirlo
   if [ -n "$desctipo" ]; then
      rcommand "$usuario" "$password" "<?php echo __DIR__.'/register.sh'; ?>" "$tipo" "$mac" "<?php echo abspath(HOSTS); ?>" "'$desctipo'" $reciente
      if [ $? -ne 0 ]; then
         cancel "Imposible registrar el tipo. ¿Desea salir?"
      else
         break
      fi
   # Si no hay que hacer la inscripción, comprobamos al menos que se puede acceder.
   elif rcommand "$usuario" "$password" true; then
      break
   else
      cancel "Acceso imposible. ¿Desea cancelar?"
   fi
   usuario=
   password=
done

# Pedimos el nombre de la imagen
nombre=$(sugerir_nombre)
while true; do
   nombre=$(pregunta_nombre "$nombre") 

   case $? in
      0) ;;
      1) error "Se requiere un nombre" 
         continue
         ;;
      2) cancel "¿Desea cancelar la creación?"
         continue
         ;;
   esac

   if ! es_nombre_valido "$nombre"; then
      error "Nombre inválido: debe ser una palabra"
   elif existe_nombre "$nombre"; then
      error "El nombre ya existe"
   else
      desc=$(pregunta_descnombre "$nombre")
      break
   fi
done

# Fijamos la visibilidad de la imagen
# (y se entrecomillas las visibilidades, para crear luego el json)
visibilidad=$(pregunta_visibilidad "$tipo" "$aula" | sed -r 's:\S+:"&":g')


# ¿Apagar el servidor al acabar?
sugerencia=""
[ $server_off -eq 1 ] && sugerencia=2
while [ "$ask_server_off" = "1" ]; do
   lapso=$(pregunta_lapso "$sugerencia" $server_off)
   case $? in
      0) break;;
      1) sugerencia=$lapso;;
      2) cancel  "¿Desea cancelar la creación?";;
   esac
done


# Fija el nombre del directorio donde se almacena la imagen
dirname=$(set_dirname "$nombre") 

# Creamos y montamos directamente el directorio que contiene los
# ficheros de imagen. Esto permite decirle siempre a clonezilla
# que la imagen se llama "."
while true; do
   rcommand "$usuario" "$password" "mkdir -p $dirname" && \
   echo "$password" | sshfs -o StrictHostKeyChecking=no,password_stdin $usuario@$nfsserver:$dirname /home/partimag && break
   cancel "Directorio remoto inaccesible. ¿Desea salir?"
done

# Creamos la descripción de la imagen en formato json
echo "{
   \"nombre\": \"$nombre\",
   \"desc\": \"$desc\",
   \"visibilidad\": [$(join_by , $visibilidad)]
}" > /home/partimag/"$descfile"


[ -z "$lapso" ] || rcommand "$usuario" "$password" "<?php echo __DIR__.'/shutdown.sh'; ?>" "$dirname" $lapso 1
