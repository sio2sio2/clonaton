<?php 

/**
 * Codifica la salida para que syslinux sea
 * capaz de mostrar los acentos.
 * @param string content  Texto con el menú de syslinux
 * @param force true, si se quiere forzar la codificación
 * aunque no sea syslinux el que pretende obtener el fichero.
 *
 * @return string
 */
function encoder($content, $force = false) {
   $client_is_syslinux = $force || stripos($_SERVER["HTTP_USER_AGENT"], "Syslinux") !== false;
   if(!$client_is_syslinux) return $content;

   # Si podemos determinar la codificación del fichero
   # lo hacemos, si no presuponemos que se trabaja con UTF-8.
   if(function_exists("mb_detect_encoding")) {
      $encoding = mb_detect_encoding($content);
   }
   else $encoding = "UTF-8";

   return iconv($encoding, "CP437", $content);
}

/**
 * Comprueba si un cadena acaba de una determinada forma
 * @param string $str  La cadena a comprobar.
 * @param string $end  La terminación que se comprueeba.
 *
 * @return bool
 */
function str_endswith($str, $end) {
   return substr($str, -strlen($end)) === $end;
}

/**
 * Devuelve la ruta relativa del script.
 * @return string
 */
function site_url() {
   list($uri, $args) = explode("?", $_SERVER['REQUEST_URI']);
   return "http".($_SERVER['HTTPS']?"s":"")."://".$_SERVER['HTTP_HOST'].$uri;
}


/**
 * Devuelve la ruta absoluta de un recurso
 * @param string path Ruta relativa del recurso.
 *
 * @return string
 */
function abspath($path) {
   if($path[0] !== "/") {  # Sólo si la ruta no es absoluta.
      $dir = substr($path, 0, strpos($path, "/", 3));

      switch($dir) {
         case "../cfg":
            $rootdir = APPDIR;
            # Hay que sustituir ../cfg por ../clonaton
            $base = substr(APPDIR, strrpos(APPDIR, "/"));
            $path = "..$base".substr($path, strlen(CFGDIR));
            break;
            
         default:
            $rootdir = TFTPDIR;
            break;
      }

      $path = $rootdir."/".$path;
   }
   return file_exists($path)?realpath($path):$path;
}


/**
 * Checks if a given IP address matches the specified CIDR subnet.
 * From: https://gist.github.com/tott/7684443#gistcomment-2108696
 *
 * @param string $ip The IP address to check
 * @param mixed $cidrs The IP subnet (string) or subnets (array) in CIDR notation
 * @param string $match optional If provided, will contain the first matched IP subnet
 *
 * @return boolean TRUE if the IP matches a given subnet or FALSE if it does not
 */
function ipMatch($ip, $cidrs, &$match = null) {
   foreach((array) $cidrs as $cidr) {
      list($subnet, $mask) = explode('/', $cidrs);
      if(((ip2long($ip) & ($mask = ~ ((1 << (32 - $mask)) - 1))) == (ip2long($subnet) & $mask))) {
         $match = $cidr;
         return true;
      }
   }
   return false;
}

/**
 * Toma un diccionario cuyas claves son los nombres de los parámetros
 *  y cuyos valores son los valores de los mismos y genera la línea de
 *  parámentros. Por ejemplo, al pasar array("a" => "1", "b" => null, "c" => "3")
 *  se obtiene la cadena "a=1 b c=3".
 *  @param Array $array La definición de los parámetros.
 *
 *  @return string  La línea de argumentos que se pasa al núcleo.
 */
function makeAppend($array) {
   $res = [];
   foreach($array as $k => $v) {
      if($v === null) array_push($res, $k);
      else array_push($res, "$k=".((strpos($v, " ") === false)?$v:'"'.$v.'"'));
   }
   return implode(" ", $res);
}

/**
 * Elimina de la dirección del sitio la ruta al fichero de configuración, es decir,
 * pxelinux.cfg/MAC-DEL-EQUIPO
 */
function base_url() {
   global $site_url;

   return dirname(dirname($site_url));
}

?>
