<?php

require_once(__DIR__."/config.php");
require_once(__DIR__."/../../lib/sysmenu.php");

class ScriptCfg extends MenuCfg {

   protected function parseDesc() {
      global $params;

      $type = $params->get('type');
      if(!$type) $type = "desc." ;

      $this->titulo = "Serv. clonaciones ({$type} en ".$params->get('room').")"; 
      $this->initCfgs = [];
   }

   protected function getModules() {
      # Los nombres de fichero se inventan para que la indentación sea la adecuada.
      $base = new CloneBaseCfg("00.M-clon/00.base", clonezilla\BLABEL);

      # Si la entrada manual falla, es que clonezilla
      # no está instalado y no hay nada más que hacer.
      if($base->fail) {
         $this->fail = $base->fail;
         $this->modules = [];
      }
      else {
         $clonables = new ListImagesCfg("00.M-clon/03.S-imagenes", "clonables");
         $this->modules = [
            $base,
            new ManualCfg("00.M-clon/01.manual", clonezilla\SYSTEM),
            new CreateCfg("00.M-clon/02.creacion", "cimagen"),
            $clonables
         ];
         if($clonables->discarded) {
            $inclonables = new OtherImagesCfg("00.M-clon/03.S-noimagenes", "noclonables");
            $inclonables->setModules($clonables->discarded);
            array_push($this->modules, $inclonables);
         }
      }
   }
}

/**
 * Superclase para las clases que generen entradas individuales.
 * Rectifica FileCfg para no leer de fichero y obligar a crear
 * un método prepareContent con el texto de la entrada (excepto LABEL).
 */
abstract class EntryCfg extends FileCfg {

   public function __construct($file, $label) {
      $this->file = $file;
      $this->label = $label;

      $this->checkDeps();

      if(!$this->fail) $this->prepareContent();
   }

   protected function checkDeps() {
      return;
   }

   abstract protected function prepareContent();

   public static function getVisibilidad($visibs) {
      global $params;

      $type = $params->get('type');
      $room = $params->get('room');

      foreach($visibs as $v) {
         list($itype, $iroom) = explode("@", $v);
         if(!$itype) $itype="*";
         if(!$iroom) $iroom="*";
         if($itype !== "*" && $itype !== $type) continue;
         if($iroom !== "*" && $iroom !== $room) continue;
         return array($itype, $iroom);
      }
      return false;
   }
}

/**
 * Base que se toma para construir las entradas que hacen uso
 * de clonezilla para ejecutar un sistema de arranque.
 */
class CloneBaseCfg extends EntryCfg {

   private static $deps = array(
      "vmlinuz",
      "initrd.img",
      "filesystem.squashfs"
   );

   /**
    * Añade al nombre del fichero, la ruta relativa hasta él.
    */
   protected static function pathFile($file) {
      return \clonezilla\SSOODIR."/".$file; 
   }

   /**
    * Comprueba si se satisfacen las dependencias
    *
    * @return bool
    */
   public function checkDeps() {
      $deps = array_map( "self::pathFile", self::$deps);
      foreach($deps as $file) {
         if(!file_exists(abspath($file))) {
            $this->fail = "# {$this->label}: $file no existe. Clonezilla no está instalado";
            return;
         }
      }
   }

   protected function prepareContent() {
      list($kernel, $initrd, $fetch) = array_map("self::pathFile", self::$deps);

      $args = array(
         'initrd'                => $initrd,
         'boot'                  => 'live',
         'config'                => null,
         'noswap'                => null,
         'nolocales'             => null,
         'edd'                   => "on",
         'nomodeset'             => null,
         'noprompt'              => null,
         "ocs_live_batch"        => "yes",
         "ocs_live_extra_param"  => "",
#         "ocs_live_keymap"       => "/usr/share/keymaps/i386/qwerty/es.kmap.gz",
#         "ocs_lang"              => "es_ES.UTF-8",
         "keyboard-layouts"      => "es",
         "locales"               => "es_ES.UTF-8",
         "vga"                   => "788",
         "nosplash"              => null,
         "fetch"                 => base_url()."/".$fetch
      );

      $this->content = implode("\n", array(
         'MENU LABEL Entrada ful',
         'KERNEL '.$kernel,
         'APPEND '.makeAppend($args),
         'MENU HIDE',
         'TEXT HELP',
	 "<\t\tEsta entrada nunca debería aparecer en el menú:",
	 "<\t\tsirve tan sólo como base para el resto",
         'ENDTEXT'
      ));
   }
}

/**
 * Arranque manual de clonezilla.
 */
class ManualCfg extends EntryCfg {

   protected function prepareContent() {
      $args = array("ocs_live_run" => "ocs-live-general");

      $this->content = implode("\n", array(
         'MENU LABEL Clone^zilla (ejecución manual)',
         'COM32 cmd.c32',
         'APPEND '.clonezilla\BLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tArranca clonezilla de modo normal para permitir",
         "<\t\tla recuperación o creación de forma manual",
         'ENDTEXT'
      ));
   }
}

/**
 * Crear una imagen de disco.
 */
class CreateCfg extends EntryCfg {

   private $prescript = "create/prescript.php";
   private $postscript = "create/postscript.php";
   private $hddetect = "create/hddetect.sh";

   private function get_url($script) {
      return base_url()."/../cfg/modules/clonezilla/scripts/".$script;
   }

   protected function prepareContent() {
      global $params;

      $removible = clonezilla\REMOVIBLE?"x":"";
      $ask_user = clonezilla\ASKUSER?"":"x";

      switch(clonezilla\COMPRESSOR) {
         case "xz":
            $opts = "-z5p";
            break;
         case "bz":
            $opts = "-z2p";
            break;
         case "gz":
         default:
            $opts = "-z1p";
      }

      $opts .= clonezilla\POSTCHECK?"":" -scs";
      $opts .= " -l ".clonezilla\MAXSIZE;
      $opts .= clonezilla\PRECHECK_NTFS?"":" -ntfs-ok";
      

      $args = array(
         # El nombre de la imagen es ".", porque se usa la argucia de montar
         # directamenmte con ssh el directorio donde se almacenará la imagen,
         # para lo cual prescript.sh debe haberlo creado previamente.
         'ocs_live_run' => "/tmp/ocs-sr -q2 -j2 $opts -sfsck -senc -noabo -rm-win-swap-hib -p true savedisk .",
         'echo_ocs_prerun' => 'no',
         'echo_ocs_postrun' => 'no',
         'ocs_prerun1' => 'wget -qO /tmp/pr.sh '.$this->get_url($this->prescript."?mac=".$params->get('mac')),
         'ocs_prerun2' => 'sleep 1;chmod +x /tmp/pr.sh;/tmp/pr.sh || { sleep 5;sudo poweroff; }',
         'ocs_prerun3' => 'wget -qO /tmp/hd.sh '.$this->get_url($this->hddetect),
	 'ocs_prerun4' => "sh /tmp/hd.sh '$removible' '$ask_user'",
         'ocs_postrun1' => 'wget -qO /tmp/po.sh '.$this->get_url($this->postscript."?mac=".$params->get('mac')),
         'ocs_postrun2' => 'sh /tmp/po.sh',
         'ocs_postrun3' => 'sleep 1; sudo poweroff',
      );

      $this->content = implode("\n", array(
         "MENU LABEL ^Crear imagen de ".$params->get('type')." [".$params->get('mac')."]",
         'COM32 cmd.c32',
         'APPEND '.clonezilla\BLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tClona los discos duros del equipo",
         'ENDTEXT'
      ));
   }
}

class ListImagesCfg extends SectionCfg {

   # Imágenes descartadas que no cumplen la visibilidad.
   public $discarded;

   protected function parseDesc() {
      global $params;

      $type = $params->get('type');
      if(!$type) $type = "desc." ;

      $this->titulo = "\t\t--Imágenes para $type en ".$params->get('room')."--";
      $this->initCfgs = [];
   }

   # Cada imagen creada debe tener, además, un fichero .desc.json
   # con el siguiente contenido:
   # {
   #   "nombre": "NombreDeLaImagen",
   #   "desc": "Pequeña descripción de la imagen",
   #   "visibilidad": [ "tipo1@aula1", "tipo2", "@aula2" ]
   # }
   protected function getModules() {
      $this->modules = [];
      $this->discarded = [];
      # Buscamos las imágenes.
      foreach(glob(\clonezilla\IMGDIR."/*" ) as $image) {
         if(!is_dir($image)) continue;
         $image = new ImageCfg($this->file."/00.M-image", $image);
         if($image->fail) continue;
         if($image->visibilidad) array_push($this->modules, $image);
         else array_push($this->discarded, $image);
      }
   }
}

class OtherImagesCfg extends MenuCfg {

   protected function parseDesc() {
      global $params;

      $type = $params->get('type');
      if(!$type) $type = "desc." ;

      $this->titulo = "\t\t--Otras imágenes--";
      $this->initCfgs = [];
   }

   protected function getModules() {
      $this->modules = [];
   }

   public function setModules($modules) {
      $this->modules = $modules;
   }
}

class ImageCfg extends MenuCfg {

   protected $separator = false;
   protected $image;  // Ruta completa al directorio de la imagen.
   public $visibilidad;

   protected function parseDesc() {
      $this->image = $this->label;
      $desc = $this->image."/".clonezilla\DESCIMG;
      if(!file_exists($desc)) {
         $this->fail = "# $image: Descripción inexistente";
         return;
      }

      $desc = self::parseDescrImg($desc);
      $this->label = $desc['nombre'];
      $this->visibilidad = EntryCfg::getVisibilidad($desc['visibilidad']);
      $this->titulo = $this->label;
      if($this->visibilidad) $this->titulo .= " (".implode("@", $this->visibilidad).")";
      $this->initCfgs = [];
   }

   public static function parseDescrImg($desc) {
      $desc = json_decode(file_get_contents($desc), true);
      return array(
         'nombre' => $desc['nombre'],
         'desc' => $desc['desc'],
         'visibilidad' => $desc["visibilidad"]
      );
   }

   protected function getModules() {
      $this->modules = array(new ImgInfoCfg($this->file."/00.info", array($this->image, $this->label)));
      # Todas las imágenes se pueden ver, pero sólo
      # las visibles se pueden recuperar.
      if($this->visibilidad) array_push($this->modules, new ImgActionsCfg($this->file."/00.S-actions", array($this->image, $this->label)));
      array_push($this->modules, new ImgEditCfg($this->file."/00.S-edition", array($this->image, $this->label)));
   }

}


/**
 * Crea la entrada que muestra la información sobre la imagen.
 * Aparte de la entrada, requiere crear un fichero en el sistema
 * que contenga esa información (MENU HELP lee de un fichero).
 */
class ImgInfoCfg extends EntryCfg {

   protected function prepareContent() {
      list($this->image, $this->label) = $this->label;

      $helpfile = \TMPDIR."/".$this->label;

      $this->content = implode("\n", array(
         "MENU LABEL ^Identificación",
         "MENU HELP $helpfile"
      ));

      # Si ya se creó anteriormente el fichero,
      # no es necesario escribirlo otra vez
      if(file_exists($helpfile)) {
         $this->label = "-";
         return;
      }

      $desc = ImageCfg::parseDescrImg($this->image."/".clonezilla\DESCIMG);
      $this->desc = $desc["desc"];
      $this->visibilidad = $desc["visibilidad"];

      $text = array_merge(array(
         "Identificación: ".$this->label." -- Creada el ".date('j \d\e M \d\e Y', filemtime($this->image."/disk")).".",
         "   ".$this->desc,
         "",
         "Visibilidad: ",
         "   ".implode(" -- ", $this->visibilidad),
         ""
      ), $this->getDiskInfo());

      file_put_contents(abspath($helpfile), encoder(implode("\n", $text), true));
      $this->label = "-";

   }

   /**
    * Calcula el tamaño corregido de disco, o sea, el tamaño de disco mínimo
    * capaz de contener las particiones de la imagen.
    */
   private function getSize($disk) {
      $content = file_get_contents($this->image."/$disk-chs.sf");
      preg_match_all("/=([0-9]+)/", $content, $matches);
      $chs = array_reduce($matches[1], function($carry, $item) { return $carry*$item; }, 1);
      $size = $chs*512;  # Tamaño en bytes.
      foreach(array("B", "KB", "MB", "GB") as $unidad) {
         if($size < 1000) return sprintf("%.2f%s", $size, $unidad);
         $size /= 1024;
      } 
      return $size;
   }

   private function getDiskInfo() {
      $content = array("Discos:");
      foreach(glob($this->image."/*.compact") as $file) {
         $handle = fopen($file, "r");
         if(!$handle) continue;
         $disk = false;
         while(($line = fgets($handle)) !== false) {
            if(!$disk && preg_match('/^Disk\s+\/dev\/([^:]+):\s*(.+)/', $line, $matches)) {
               $disk = $matches[1];
               array_push($content, sprintf("   %3s.- %-6s (en origen %s):", $disk, $this->getSize($disk), $matches[2]));
            }
	    # TODO: Comprobar si en las tablas de particiones MSDOS aparece antes el nombre que el tipo 
            else if($disk && preg_match("/^\s*([0-9]+)(?:\s+\S+){2}\s+(\S+)\s+(\S+)(?:\s+(\S+(?: \S+)?))?/", $line, $matches)) {
               array_push($content, sprintf("      %5s: %6s :: %4s (%s)", $disk.$matches[1], $matches[2], $matches[3], $matches[4]??"no label"));
            }
         }
      }
      return $content;
   }

}


class ImgEditCfg extends SectionCfg {

   protected function parseDesc() {
      $this->titulo = "Edición";
      $this->initCfgs = [];
   }

   protected function getModules() {
      $this->modules = [
         new ImgRenameCfg($this->file."/00.rename", $this->label),
         new ImgChangeCfg($this->file."/00.change", $this->label),
         new ImgDelCfg($this->file."/00.delete", $this->label)
      ];
      $this->label = "-";
   }
}

class ImgRenameCfg extends EntryCfg {

   protected function prepareContent() {
      list($image, $label) = $this->label;

      $launch = CFGDIR.'/modules/clonezilla/scripts/launch.sh';
      $script = abspath(CFGDIR.'/modules/clonezilla/scripts/rename.sh');

      $args = array(
         'script' => base_url()."/$launch '$script' '$image'"
      );

      $this->label = "r".$label;

      $this->content = implode("\n", array(
         "MENU LABEL ^Renombrar",
         'COM32 cmd.c32',
         'APPEND '.SCRLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tModifica el nombre de la imagen ".$label,
         'ENDTEXT'
      ));

   }
}

class ImgChangeCfg extends EntryCfg {

   protected function prepareContent() {
      global $params;

      list($image, $label) = $this->label;

      $launch = CFGDIR.'/modules/clonezilla/scripts/launch.sh';
      $script = abspath(CFGDIR.'/modules/clonezilla/scripts/chvisib.sh');


      $args = array(
         'script' => base_url()."/$launch '$script' '$image'  '${params['type']}' '${params['room']}'"
      );

      $this->label = "m".$label;

      $this->content = implode("\n", array(
         "MENU LABEL ^Modificar la visibilidad",
         'COM32 cmd.c32',
         'APPEND '.SCRLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tModifica la visibilidad de la imagen ".$label,
         'ENDTEXT'
      ));

   }
}

class ImgDelCfg extends EntryCfg {

   protected function prepareContent() {
      list($image, $label) = $this->label;

      $launch = CFGDIR.'/modules/clonezilla/scripts/launch.sh';
      $script = abspath(CFGDIR.'/modules/clonezilla/scripts/delete.sh');
      
      $args = array(
	   # Escribir directamente el script, sigue funcionando
#         'script' => "read -p 'Usuario SSH: ' U;".
#                        "ssh -t -y \\\$U@{$_SERVER['HTTP_HOST']} '$script' '$image';".
#                        "echo -en 'Que desea hacer?\\n   [p]oweroff\\n   [r]eboot\\n   [c]ommand line\\n> ';read -n1 -t30 A;".
#                        "case \\\"\\\$A\\\" in r)reboot;;p)poweroff;;*) . /etc/profile;sh;;esac"
         'script' => base_url()."/$launch '$script' '$image'"
      );

      $this->label = "d".$label;

      $this->content = implode("\n", array(
         "MENU LABEL ^Borrar",
         'COM32 cmd.c32',
         'APPEND '.SCRLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tBorrar del servidor la imagen ".$label,
         'ENDTEXT'
      ));
   }
}

class ImgActionsCfg extends SectionCfg {

   protected function parseDesc() {
      $this->titulo = "Operaciones";
      $this->initCfgs = [];
   }

   protected function getModules() {
      $file = $this->file."/00.multicast";
      $this->modules = [
         new MulticastCfg($file, $this->label),
         new UnicastCfg($this->file."/01.unicast", $this->label)
      ];
      $this->label = "-";
   }
}

class UnicastCfg extends EntryCfg {

   protected function prepareContent() {
      list($image, $label) = $this->label;

      $dirbase = dirname($image);
      $dirimg = basename($image);

      # Si hay más de un dispositivo en la imagen, preguntamos.
      $devices = trim(file_get_contents("$image/disk"));
      if(str_word_count($devices)>1 && clonezilla\ASKUSER) $devices = "ask_user";

      $check = clonezilla\PRECHECK?"":"-scr";

      # Comprobar cuáles son los parámetros necesarios.
      $args = array(
         "ocs_live_run" => "/usr/sbin/ocs-sr --batch -g auto -e1 auto -e2 -r -j2 $check -p ".clonezilla\UNI_POSTACTION." restoredisk $dirimg $devices",
         "ocs_prerun" => "mount -t nfs -o ro,vers=3 ".$_SERVER['HTTP_HOST'].":".clonezilla\IMGDIR." /home/partimag"
      );

      $this->label = "u".$label;

      $this->content = implode("\n", array(
         "MENU LABEL Restaurar (^unicast)",
         'COM32 cmd.c32',
         'APPEND '.clonezilla\BLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tRestaura por unicast la imagen ".$label,
         'ENDTEXT'
      ));

   }
}

/**
 * Genera la entrada para multicast
 */
class MulticastCfg extends EntryCfg {

   protected $image;
   static public $aulas = [];  # Relaciona las interfaces con las aulas.

   /**
    * Indica cuál es el aula asociada a una interfaz.
    */
   static public function getAula($iface) {
      if(self::$aulas) return self::$aulas[$iface];

      $handle = fopen(abspath(NETWORKS), "r");
      if(!$handle) return;
      while(($line = fgets($handle)) !== false) {
         list($aula, $_, $interfaz, $_) = explode(",", $line);
         self::$aulas[$interfaz] = $aula;
      }
      return self::$aulas[$iface];
   }

   /**
    * Obtiene los nombres de las imágenes que tienen
    * lanzada una clonación multicast en una interfaz determinada.
    * $iface: La interfaz por la que se lanza (null, si se quieren revisar todas)
    *
    * @return Array Una lista donde cada elemento es (interfaz, nombre_imagen)
    */
   private static function getMulticast($iface) {
      $files = glob(self::substituteVars(clonezilla\MULTICAST, ['image' => '*', 'iface' => $iface??"*"]));
      if(!$files) return array();
      # Cada "multicast_iface_nombre.php" se convierte en (iface, nombre)
      return array_map(function($name) {
         $pattern = clonezilla\MULTICAST;
         for($j=strlen($name)-1, $k=strlen($pattern)-1; $j >=0 && $k >=0; $j--, $k--) if($name[$j] !== $pattern[$k]) break;
         $name = explode("_", substr($name, 0, $j+1));  # Quitamos .php y separamos por _
         array_shift($name);  # Quitamos "multicast_"
         $iface = $name[0];
         array_shift($name);  # Quitamos la interfaz.
         return [ $iface, implode("_", $name) ];
      }, $files);
   }

   protected function prepareContent() {
      global $params;

      list($this->image, $this->label) = $this->label;

      $images = self::getMulticast(clonezilla\MULTIUNIQUE?null:$params['iface']);
      if(!$images) $this->launchMulti();
      elseif(in_array([$params['iface'], $this->label], $images)) $this->restoreMulti();
      else $this->noMulti(implode(", ", array_map(function($img) {
         return $img[1]."@".self::getAula($img[0]);
      }, $images)));
   }

   private function restoreMulti() {
      global $params;
      # Define $ocs_live_run_params y $help
      include(self::substituteVars(clonezilla\MULTICAST, ['image' => $this->label, 'iface' => $params['iface']]));

      $args = array(
         "ocs_live_run" => "/usr/sbin/ocs-sr $ocs_live_run_params",
         "ocs_prerun"   => "mount -t nfs -o ro,vers=3 ".$_SERVER['HTTP_HOST'].":".clonezilla\IMGDIR." /home/partimag",
         "ocs_server"   => $_SERVER['HTTP_HOST']
      );

      $this->label = "m".$this->label;

      $this->content = implode("\n", array(
         "MENU LABEL Restaurar (^multicast)",
         'COM32 cmd.c32',
         'APPEND '.clonezilla\BLABEL.' '.makeAppend($args),
	 "TEXT HELP",
	  $help,
         'ENDTEXT'
      ));
   }

   private function launchMulti() {
      global $params;

      $launch = CFGDIR.'/modules/clonezilla/scripts/launch.sh';
      $script = abspath(CFGDIR.'/modules/clonezilla/scripts/dcs.sh');
      
      $args = array(
         'script' => base_url()."/$launch '$script' -r '".$params->get('room')."' startdisk '".$this->image."'"
      );

      $this->content = implode("\n", array(
         "MENU LABEL ^Lanzar multicast",
         'COM32 cmd.c32',
         'APPEND '.SCRLABEL.' '.makeAppend($args),
         'TEXT HELP',
         "<\t\tLanza una clonación multicast de {$this->label}",
         'ENDTEXT'
      ));

      $this->label = "lm".$this->label;
   }

   private function noMulti($clonando) {
      $this->label = "-";
      $this->content = implode("\n", array(
         "MENU LABEL Restaurar (multicast) -- clonando $clonando",
         "MENU DISABLE"
      ));
   }
}
?>
