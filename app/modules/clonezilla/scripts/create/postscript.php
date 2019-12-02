<?php
require(__DIR__."/../../utils.php");
header("Content-Type: text/plain");
?>
#!/bin/sh
#
# Tareas de postclonado de la imagen:
#
# 1) Ajustar el tamaño del disco al final de la última partición.
# 2) Hacer legible la imagen para todos los usuarios.
# 3) Renombra la descripción para saber que la imagen se acabó
#    con éxito.
#
# Las tareas se realizan en /home/partimage, sobre el que prescript
# había montado el directorio remoto, con lo que no es necesario obtener
# ningún dato de configuración del servidor.

MOUNTDIR=/home/partimag
BYTESSECTOR=512
PARTEDFILE=sd{{letra}}-pt.parted
GEOFILE=sd{{letra}}-chs.sf
DESCFILE="<?php echo clonezilla\DESCIMG; ?>"

#
# Devuelve el mínimo de dos números enteros
#
min() {
   [ "$1" -lt "$2" ] && echo "$1" || echo "$2"
}

# Obtiene el nombre del fichero, al sustituir la letra por su valor
# $1: La plantilla que forma el nombre.
# $2: La letra que representa el disco (si es sda, la a).
get_file() {
   echo "$MOUNTDIR/$1" | sed -r 's:\{\{letra\}\}:'"$2:"
}

# Calcula el último sector de la última partición
# $1: El fichero que contiene la descripción de las particiones.
get_last() {
   awk -Fs '/^ +[0-9]+/ {print $2}' "$1" | sort -n | tail -n1
}

# Calcula el número de cilindros del disco.
# $1: Último sector
get_cylinders() {
   echo $(($1/sectors/heads + 1))
}

# Obtiene el tamaño en la unidad indicada
# $1: Tamaño en sectores
# $2: Unidad en la que se quiere obtener el tamaño
get_size() {
   local MB=$((1024*1024))
   local GB=$((MB*1024))
   local TB=$((GB*1024))

   eval echo '$(($1*BYTESSECTOR/'$2'))'
}

# 1) Ajuste de tamaño.
for disk in $(cat "$MOUNTDIR"/disk); do
   letra=${disk#sd}
   pfile=$(get_file "$PARTEDFILE" $letra)
   gfile=$(get_file "$GEOFILE" $letra)
   . "$gfile"
   last_sector="$(get_last $pfile)"
   ocylinders="$cylinders"
   cylinders=$(get_cylinders $last_sector)

   echo "cylinders=$(min $cylinders $ocylinders)
heads=$heads
sectors=$sectors" > "$gfile"

   # Ajustamos el tamaño en sd?-pt.parted
   tam=$(min `sed -r '/^Disk/!d; s|^.*:\s*([0-9]+).*$|\1|; q' "$pfile"` $((cylinders*heads*sectors)))
   sed -ri '/^Disk/s:[0-9]+s:'$tam's:' "$pfile"

   # Ajustamos el tamaño en sd?-pt.parted.compact
   unidad=$(sed -r '/^Disk/!d; s:^.*(..)$:\1:; q' "$pfile".compact)
   tam=`get_size "$tam" "$unidad"`
   sed -ri '/^Disk/s:[0-9]+(..)$:'$tam'\1:' "$pfile".compact
done

# 2) Legibilidad. (ya lo hace la opción -noabo)
# chmod +r "$MOUNTDIR"/sd[a-z][1-9]*

# 3) Eliminamos la terminación tmp.
mv "$MOUNTDIR/$DESCFILE".tmp "$MOUNTDIR/$DESCFILE"
