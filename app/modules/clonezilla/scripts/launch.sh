#!/bin/sh
#
# Cargador de los scripts que el cliente ejecuta conectándose por ssh
# al servidor.
# $1: Servidor al que conectarse por SSH.
# $2: Script del servidor que debe ejecutarse.
# $3 ...: Argumentos que deben pasarse al script

alias dialog="dialog --backtitle 'Cacharreo Free Software Labs' --title 'Gestion de imagenes'"

#
# Muestra un mensaje de error con dialog
#
error() {
   dialog --msgbox "$1" 7 55
}

#
# Cancela la ejecución del script
#
cancel() {
   dialog --yesno "$1" 7 55 && menu_final 1
}


#
# Determina cuál es la orden que desea ejecutarse.
# $1: El script tal como se pasa al programa
#
get_script() {
   local script=$1 dirname

   # Es una ruta absoluta o una orden del sistema
   if [ -z "${scrip%%/*}" ] || type $script > /dev/null; then
      echo $script 
   else
      return 1
   fi
}

#
# Comprueba si el usuario es válido
#
es_usuario_valido() {
   echo $1 | egrep -q '^[-[:alnum:]_.]+$'
}


#
# Pregunta un usuario de acceso al servidor SSH
#
pregunta_usuario() {
   local usuario=$1

   usuario=$(dialog --inputbox "Usuario con acceso SSH" 7 45 "$usuario" 3>&1 1>&2 2>&3) || return 2
   es_usuario_valido "$usuario" || return 1

   echo $usuario
}


pregunta_password() {
   dialog --passwordbox "Contraseña" 7 45 3>&1 1>&2 2>&3 || return 2
}

#
# Pregunta la acción que cierra el programa
# $1: Si es 255, debe añadirse como acción "restart"
#
preguntar_accion() {
   local items num

   items="poweroff Apagar
          reboot Reiniciar
          restart 'Intentar de nuevo'
          cmd 'Entrar en SliTaZ'"

   num=$(echo "$items" | wc -l)

   eval dialog --no-ok --no-cancel --menu "'Escoja qué desea hacer'" $((8+num)) 40 $num $items '3>&1 1>&2 2>&3'
}

#
# Encierra entre comillas los argumentos
#
prepare_args() {
   local arg

   for arg in "$@"; do
      echo -n "'$arg' "
   done
}


#
# Presenta el menú final
#
menu_final() {
   local status=$1 action

   while [ -z $action ]; do
      action=$(preguntar_accion)
   done

   case $action in
      reboot) reboot;;
      poweroff) poweroff;;
      cmd) exit $status;;
      restart) usuario=;;
   esac
}

if [ $# -gt 1 ]; then
   server=$1
   script=$(get_script $2) || { error "Ruta relativa no soportada" && exit 1; }
   shift 2
else
   error "Se requiere un script remoto"
   exit 1
fi

while true; do
   while [ -z "$usuario" ]; do
      usuario=$(pregunta_usuario "$usuario")
      case $? in
         0) break;;
         1) error "Nombre inválido de usuario";;
         2) cancel "¿Desea cancelar la acceso?";;
      esac
   done

   while true; do
      if password=$(pregunta_password); then
         break
      else
         cancel "¿Desea cancelar el acceso?"
      fi
   done

   # Accedemos al servidor y ejecutamos el script
   DROPBEAR_PASSWORD=$password ssh -t -y $usuario@$server "$script" $(prepare_args "$@")

   menu_final 0
done
