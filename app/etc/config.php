<?php

require_once(__DIR__."/../lib/utils.php");
require_once(__DIR__."/../lib/params.php");

define("COMPACT", true);               # Menús compactos.
define("VERBOSE", true);               # Muestra deshabilitadas las entradas que no cumplen dependencias.
define("SHIFTKEY", true);              # Require shift para mostrar el menú.
define("TFTPDIR", "/srv/tftp/bios");   # Localización de lpxelinux.0
define("APPDIR", dirname(__DIR__));    # Directorio de la aplicación
define("UI", "menu.c32");              # Interfaz de syslinux.
define("TIMEOUT", 0);                  # Temporización del menú.

define("CFGDIR", "../cfg");            # Directorio de la aplicación (servidor web)
define("SSOODIR", "../ssoo");          # Directorio de sistemas operativos.
define("HOSTS", CFGDIR."/etc/hosts");          # Definición de tipos de máquinas.
define("NETWORKS", CFGDIR."/etc/networks");    # Definición de aulas.
define("TMPDIR", CFGDIR."/cache");     # Directorio de ficheros de información sobre imágenes
define("ITEMSDIR", CFGDIR."/items");    # Directorio base de entradas de los menús.
define("SCRLABEL", "slitaz");          # Etiqueta del sistema que se usará para ejecutar scripts
$site_url = site_url();

$params = new ParamsObject(SHIFTKEY);
