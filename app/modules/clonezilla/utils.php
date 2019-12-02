<?php

require_once(__DIR__."/config.php");
require_once(__DIR__."/../../etc/config.php");
require_once(__DIR__."/../../lib/utils.php");

/**
 * Devuelve los tipos de máquinas ya definidos
 * y su descripción en la forma:
 *
 * tipo1=Descripción del tipo 1
 * tipo2=Descripción del tipo 2
 */
function lista_tipos() {

   $lines = array_map(function($line) {
      $line = trim($line);
      if(!$line || $line[0] === "#") return;
      $tipo = explode(",", $line)[1];
      list($tipo, $desc) = explode("#", $tipo);
      return trim($tipo)."=".trim($desc);
   }, explode("\n", file_get_contents(abspath(HOSTS))));

   return implode("\n", array_filter($lines, function($line) { return $line !== null; }));
}

/**
 * Devuelve los nombres de las imágenes existentes en la forma:
 *
 * nombre1=Descripción imagen1
 * nombre2=Descripción imagen2
 */
function lista_imagenes() {
   $lines = array_map(function($dir) {
      $desc = $dir."/".clonezilla\DESCIMG;
      if(!file_exists($desc)) {
         $desc .= ".tmp";
         # El directorio no contiene imagen puesto
         # que no tiene descripción.
         if(!file_exists($desc)) return null;
      }
      $params = json_decode(file_get_contents($desc), true);
      return $params["nombre"]."=".$params["descripcion"];
   }, glob(clonezilla\IMGDIR."/*"));

   return implode("\n", array_filter($lines, function($line) { return $line !== null; }));
}

/**
 * Devuelve las aulas existentes en la forma:
 *
 * aula1=Red1-CIDR,iface1,Descripción del aula1
 * aula2=Red2-CIDR,iface2,Descripción del aula2
 */
function lista_aulas() {

   $lines = array_map(function($line) {
      $line = trim($line);
      if(!$line || $line[0] === "#") return;
      list($aula, $red, $iface, $desc) = array_map("trim", explode(",", $line));
      return $aula."=".$red.",".$iface.",".$desc;
   }, explode("\n", file_get_contents(abspath(NETWORKS))));

   return implode("\n", array_filter($lines, function($line) { return $line !== null; }));
}

/**
 * Obtiene las variables definidas en el fichero
 * de configuración.
 */
function parse_conf($conffile = null) {
   $ret = [];
   $conffile = $conffile??"/etc/clonaton/clonaton.conf";

   $handle = fopen($conffile, "r");
   while(($line = fgets($handle)) !== false) {
      if(!preg_match("/^([_[:alnum:]]+)\s*=\s*(.*)$/", $line, $matches)) continue;
      $ret[$matches[1]] = $matches[2];
   }

   return $ret;
}
?>
