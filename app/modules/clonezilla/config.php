<?php

namespace clonezilla;

require_once(__DIR__."/../../etc/config.php");

# Sólo se permite una recuperación multicast
# a la vez, en vez de una por aula.
define(__NAMESPACE__."\MULTIUNIQUE", true);

define(__NAMESPACE__."\SYSTEM", __NAMESPACE__);
define(__NAMESPACE__."\BLABEL", "b".SYSTEM);
define(__NAMESPACE__."\IMGDIR", "/srv/nfs/images");
define(__NAMESPACE__."\SSOODIR", \SSOODIR."/".SYSTEM);
define(__NAMESPACE__."\MULTICAST", "/tmp/multicast_{{iface}}_{{image}}.php");
define(__NAMESPACE__."\DESCIMG", ".desc.json");
# Cuando el ordenador/imagen tiene varios discos, pregunta
# cuáles se quieren clonar/restaurar.
define(__NAMESPACE__."\ASKUSER", false);
# No considera los discos extraíbles
# como candidatos a ser clonados.
define(__NAMESPACE__."\REMOVIBLE", false);
# Acción que se ordenará a los clientes
# tras hacer una restauración unicast.
define(__NAMESPACE__."\UNI_POSTACTION", "poweroff");
# Acción que se ordenará a los clientes
# tras hacer una restauración multicast.
define(__NAMESPACE__."\MULTI_POSTACTION", "poweroff");
# Compresor usado para reducir el tamaño de las imágenes.
# xz, gz, o bz.
define(__NAMESPACE__."\COMPRESSOR", "xz");
# ¿Se comprueban las imágenes antes de restaurar?
define(__NAMESPACE__."\PRECHECK", false);
# ¿Se comprueban las imágenes al acabar de crearlas?
define(__NAMESPACE__."\POSTCHECK", true);
# ¿Se comprueba NTFS antes de la clonación?
define(__NAMESPACE__."\PRECHECK_NTFS", false);
# Tamaño máximo de los ficheros de imágenes
define(__NAMESPACE__."\MAXSIZE", 4096);
# Apaga el servidor, una vez que acaben todas las operaciones en marcha.
# null, signifca que depende del tipo de servidor: sólo se apaga si el tipo es 2.
# Sólo en caso de que sea null, se pedirá confirmación al usuario.
define(__NAMESPACE__."\SERVER_OFF", null)
?>
