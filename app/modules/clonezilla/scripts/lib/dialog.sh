#
# Funciones para hacer más simple el uso de whiptail
#

# Permite ejecutar de modo sencillo dialog.
# $1: Una cadena cualquiera si el cuadro de diálogo es normal
#     o "error" si es un cuadro que muestra un error.
# $2, $3, ...: Parámetros adicionales para dialog
dialog() {
   local NEWT_COLORS IFS
   if [ "$1" = "error" ]; then
      export NEWT_COLORS="root=,red roottext=yellow,red"
      shift
   fi

   set -- --backtitle 'Cacharreo Free Software Labs' "$@"

   whiptail "$@" 3>&1 1>&2 2>&3
} 

# Si exuste ya un título, creamos alias
# para no tener que incluirlo constantemente
if [ -n "$title" ]; then
   alias dialog="dialog --title '$title'"
   alias edialog="\dialog error --title '$title'"
else
   alias edialog='\dialog error'
fi


error() {
   local msg="$1"
   [ $# -gt 0 ] && shift
   edialog "$@" --msgbox "$msg" 7 55
}


cancel() {
   local msg="$1"
   [ $# -gt 0 ] && shift
   dialog "$@" --defaultno --yesno "$msg" 7 55 && exit 255
}


#
# Devuelve la altura de un menú
# $1: Número de items del menú.
# $2: Número de líneas que se estima que ocupara la leyenda
#     (por defecto, 1).
#
menu_height() {
   local MAX=18
   local extra=${2:-1} num 
   
   num=$((7+$1+extra))
   if [ $num -lt $MAX ]; then
      echo $num
   else
      echo $MAX
   fi
}
