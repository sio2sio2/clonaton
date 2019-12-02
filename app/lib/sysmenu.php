<?php

define("DESC", ".desc");
define("INDENT","\t");

require_once(__DIR__.'/../etc/config.php');
require_once(__DIR__.'/utils.php');
require_once(__DIR__.'/params.php');


/**
 * Determina el tipo de configuración y lanza la clase apropiada.
 * @param string $file   Fichero de configuración con la ruta absoluta.

 * Los tipos de ficheros de configuración son los siguientes:
 *
 * - file: Es un fichero regular que puede ser un fichero crudo .cfg o un
 *         script "php" que representa una entrada del menú de syslinux.
 * - custom: Script de php que genera genera una o varias entradas del menú
             de syslinux. Debe tener nombre 'NN.X-etiqueta'. Puede ser un
             directorio que contenga un fichero entry.php o directamente
             un fichero (con extensión de php).
 * - section: Es un directorio con el nombre "NN.S-etiqueta", y representa una
              sección en el menú de syslinux.
 * - menu: Es un directorio con el nombre "NN.M-etiqueta" y representa un
           submenú dentro del menú de syslinux.
 * - root: Es un directorio con un nombre cualquiera que no empieza por "NN."
 *         y representa el menú principal de syslinux.
 *
 * @return Cfg
 */
function loadCfg($file) {
   if(!file_exists($file)) return null;

   $type = null;
   $label = null;

   $name = basename($file);
   $test = preg_match("/^[0-9]+\.#?([[:upper:]]-)?(.+)(?:.php)?$/", $name, $matches);

   if(is_dir($file)) {
      if($test) {
         $label = $matches[2];
         switch($matches[1]) {
            case "S-":
               $type = "section";
               break;
            case "M-":
               $type = "menu";
               break;
            default:
               $type = "module";
         }
      }
      else $type = "root";
   }
   else {
      $type = $matches[1]?"module":"file";
      $label = $test?$matches[2]:$name;
   }

   switch($type) {
      case "file":
         return new FileCfg($file, $label);
         break;
      case "root":
         return new RootCfg($file, null);
         break;
      case "section":
         return new SectionCfg($file, "-");
         break;
      case "menu":
         return new MenuCfg($file, null);
         break;
      default:
         return customCfg($file, $label);
         break;
   }
}   

/**
 * Interfaz que deben implementar todas las clases
 * que procesan ficheros (o directorios) de configuración
 */
interface Cfg {
   /**
    * Construye el objeto.
    * @param string $file   Fichero de configuración con su ruta absoluta.
    *
    * @return string
    */
   public function __construct($file, $label);
   /**
    * Devuelve el texto de la entrada que genera el fichero
    */
   public function getContents();
}

abstract class BaseCfg implements Cfg {

   protected $file;
   protected $label;
   private $indent = null;
   protected $defaultEntry = false;
   protected $separator = null;
   # Si la entrada falla (p.e. falta de deps), contendrá el mensaje de error.
   public $fail = false;

   public function __construct($file, $label) {
      $this->file = $file;
      $this->label = $label;
   }

   /**
    * Devuelve el nivel de sangrado en el menú
    * de la entrada que genera el fichero.
    *
    * @return string
   */
   protected function getLevel() {
      # Cuentas las secciones a partir del último menú.
      $start = strrpos($this->file, ".M-");
      if($start === false) $start = 0;
      return substr_count($this->file, ".S-", $start);
   }

   /**
    * Obtiene el sangrado adecuado para hacer más legible el
    * fichero de configuración (no la presentación en forma de menú).
    */
   private function getIndentation() {
      if($this->indent !== null) return $this->indent;
      $path = dirname($this->file);
      $this->indent = substr_count($path, ".S-") + substr_count($path, ".M-");
      return $this->indent;
   }

   /**
    * Aplica a una línea con el sangrado adecuado
    */
   protected function fprint($line, $extra = 0) {
      if($line[0] === "<") {
         $sangrado="";
         $line=substr($line, 1);
      }
      else {
         $sangrado=str_repeat(INDENT, $this->getIndentation() + $extra);
      }
      return $sangrado.$line;
   }

   /**
    * Marca la entrada como predeterminada.
    */
   protected function setDefault() {
      $this->defaultEntry = true;
   }

   /**
    * Establece si la entrada debe dejar antes de ella una línea separadora.
    * @param mixed $prev    Entrada anterior (null, si es la primera entrada)
    *
    * @return bool
    */
   protected function getSeparator($prev) {
      # Si ya se fijó de antemano el separador, no se calcula.
      if($this->separator !== null) return $this->separator;

      if(COMPACT || !$prev) return false;

      $modular = is_subclass_of($current, "ModularCfg");
      if($modular && (!$current->fail || VERBOSE)) return true;

      $prev_modular = is_subclass_of($prev, "ModularCfg");
      return !!$prev_modular;
   }

   /**
    * Substituye en un texto variables
    */
   public static function substituteVars($text, $extra = null) {
      global $params;

      if($extra !== null) {
         foreach($extra as $name => $value) {
            $text = str_replace("{{".$name."}}", $value, $text);
         }
      }

      foreach($params->array_keys() as $name) {
         $text = str_replace("{{".$name."}}", $params->get($name), $text);
      }
      return str_replace("{{ssoo}}", SSOODIR, $text);
   }

   abstract public function getType();

   protected function viewFail() {
      if(VERBOSE) {
         $type = $this->getType();
         # TODO: Esto es un poco chapucero. $extra debería devolverlo la propia subclase.
         switch($type) {
            case "section":
               $extra = " [--sección--]";
               break;
            case "menu":
               $extra = " [--menú--]";
               break;
            default:
               $extra = "";
         }
         $titulo = $this->titulo;
         if(!$titulo) $titulo = $this->label;
         $content = [
            "LABEL {$this->label}",
            INDENT."MENU LABEL {$titulo}$extra",
            INDENT."MENU DISABLED"
         ];
         if($this->separator) array_unshift($content, "MENU SEPARATOR\n");
         $level = $this->getLevel();
         if($level > 0) array_push($content, INDENT."MENU INDENT ".$level);
         return $content;
      }
      else return explode("\n", $this->fail);
   }

}

class FileCfg extends BaseCfg {

   protected $content;

   public function __construct($file, $label) {
      parent::__construct($file, $label);

      $this->content = file_get_contents($file);

      # Si el fichero es código PHP, debe ejecutarse.
      if(str_endswith($this->file, ".php")) $this->executePHP();

      $this->readCfg();
   }

   /**
    * Transforma el contenido PHP en el resultado de la ejecución de dicho código.
    */
   public function executePHP() {
      ob_start();
      eval(" ?>".$this->content."<?php ");  #" ?><?php
      $this->content = ob_get_contents();
      ob_end_clean();
   }

   /**
    * Sustituye en el contenido cualquier {{variable}} por su valor.
    * Además comprueba que se cumplan las dependencias de ficheros necesarios.
    * invocando checkDeps.
    */
   public function readCfg() {
      global $site_url;

      $this->content = self::substituteVars($this->content);
      $vars = $this->checkDeps();
      
      foreach($vars as $name => $value) {
         $this->content = str_replace("{{".$name."}}", $value, $this->content);
      }

      $this->content = trim(str_replace("{{site_url}}", $site_url, $this->content));
   }

   /**
    * Extrae del fichero de configuración las definiciones de ficheros:
    * #nombre=/ruta/al/fichero
    * @return Array  Diccionario con las definiciones de ficheros
    */
   protected function checkDeps() {
      $vars = array();
      $text = explode("\n", $this->content);
      $content = [];
      foreach($text as $line) {
         $total = preg_match("/^#([A-Za-z_]\w+)\s*=\s*(\S+)\s*$/", $line, $matches);
         if($total) {
            $vars[$matches[1]] = $matches[2];
            $file = $matches[2];
            if(!file_exists(abspath($file))) {
               $this->fail = "# {$this->label}: Dependencia no resuelta: $file no existe";
               if(!VERBOSE) return $vars;
            }
         }
         else {
            # TODO: Comprobar si la línea es de la forma #variable==valor.
            array_push($content, $line);
         }
      }
      $this->content = implode("\n", $content);
      return $vars;
   }

   public function getContents() {
      if($this->fail) {
         $content = $this->viewFail();
         $this->label = null;
      }
      else $content = explode("\n", $this->content);

      if($this->label) {
         $level = $this->getLevel();
         if($this->defaultEntry) array_unshift($content, "MENU DEFAULT");
         if($level > 0) { # Comprobamos que no se haya especificado el sangrado explícitamente
            $exists = false;
            foreach($content as $line) {
               if(preg_match("/^MENU\s+INDENT\b/i", $line)) {
                  $exists = true;
                  break;
               }
            }
            if(!$exists) array_unshift($content, "MENU INDENT ".$level);
         }
         $content = array_map(function($line) { return $this->fprint($line, 1); }, $content);
         array_unshift($content, $this->fprint("LABEL ".$this->label));
         if($this->separator) array_unshift($content, "MENU SEPARATOR\n");
      }
      else {
         $content = array_map(function($line) { return $this->fprint($line); }, $content);
      }

      return implode("\n", $content);
   }

   public function getType() {
      return "entry";
   }
}

/**
 * Base para las clases que representan contenedores
 * de entradas del menú (root, section, menu).
 */
abstract class ModularCfg extends BaseCfg {

   /**
    * Array que almacena los ficheros de configuración
    * que se citan en el fichero de descripción (.desc)
    * y no representan entradas, sino líneas de configuración
    * (por ejemplo, la configuración del estilo referente
    * al menú).
    */
   protected $initCfgs;

   /**
    * Módulos (entradas) que constituyen la parte de la
    * configuración representada por el objeto.
    */
   protected $modules;

   /**
    * Añade líneas de configuración iniciales
    */
   abstract protected function preambulo();

   /**
    * Añade líneas de configuración finales
    *
    * @return string
    */
   abstract protected function conclusion();

   public function __construct($file, $label) {
      $this->file = $file;
      $this->label = $label;

      $this->parseDesc();
      if(!$this->fail) $this->getModules();
   }

   /**
    * Extrae la información del fichero de descripción:
    *
    * - Primera línea: El título.
    * - Resto de líneas: Objetos que representan los ficheros de configuración
    *
    * Puede haber líneas comentadas
    */
   protected function parseDesc() {
      $this->initCfgs = [];
      $desc = $this->file."/".DESC;
      if(!file_exists($desc)) {
         $this->fail = "# {$this->label}: {$this->file} no tiene fichero de descripción";
         return null;
      }
      $handle = fopen($desc, "r");
      $this->titulo = self::substituteVars(trim(fgets($handle)));
      while(($line = fgets($handle)) !== false) {
         if(preg_match("/^\s*#/", $line)) continue;  # Obviamos comentarios.
         $file = substr($line, 0, -1);
         if(substr($file, 0, 1) !== "/") {  # No es una ruta absoluta.
            $file = $this->file."/".$file;
         }
         if(!file_exists($file)) {
            $this->fail = "# {$this->label}: {$this->file} necesita $file, pero no existe";
            return;
         }
         array_push($this->initCfgs, new FileCfg($file, null));
      }
   }

   /**
    * Obtiene los módulos que componen esta parte de la configuración
    */
   protected function getModules() {
      $this->modules = [];
      $oldcfg = null;
      foreach(glob($this->file."/[0-9]*") as $file) {
         $cfg = loadCfg($file);
         # La entrada está marcada como predeterminada.
         if(strpos($file, ".#") !== false) $cfg->setDefault();
         array_push($this->modules, $cfg);
         $cfg->separator = $this->getSeparator($cfg);
         if(!$cfg->fail || VERBOSE) $oldcfg = $cfg;
      }

      # Entradas que han fallado (almacenamos sus mensajes de fallo)
      $fails = array_filter(array_map(function($module) { return $module->fail; }, $this->modules), "boolval");

      # Si todas sus entradas fallan, entonces la entrada modular falla
      if(count($fails) === count($this->modules)) {
         array_unshift($fails, "# {$this->file}: Carece de entradas que dependan de ella");
         $this->fail = implode("\n", $fails);
      }
   }

   /**
    * Extrae las líneas de configuración de todos los ficheros
    * que forman la configuración modular.
    * @param array modularCfg  Lista de los objetos que modelan
    * la configuración modular. En principio se pasará o el
    * atributo initCfgs o el atributo modules.
    *
    * @return string
    */
   private function getCfgs($modularCfg) {
      return implode("\n\n", array_map(function($module) {return $module->getContents(); }, $modularCfg));
   }

   /**
    * Devuelve cuál es la entrada predeterminada
    */
   public function getDefaultEntry() {
      foreach($this->modules as $entry) {
         switch($entry->getType()) {
            case "menu":
            case "???":
               continue;
            case "entry":
               if($entry->defaultEntry) return $entry;
               break;
            case "section":
               if($default = $entry->getDefaultEntry()) return $default;
               break;
            default:
               continue;
         }
      }
   }

   public function getContents() {
      if($this->fail) {
         $parts = $this->viewFail();
         return implode("\n", $parts);
      }

      $parts = [
         $this->preambulo(),
         $this->getCfgs($this->initCfgs),
         $this->getCfgs($this->modules),
         $this->conclusion()
      ];
      if($this->separator) array_unshift($parts, "MENU SEPARATOR");

      return implode("\n\n", array_filter($parts, function($e) { return !empty($e); }));
   }
}

class RootCfg extends ModularCfg {

   protected function preambulo() {   
      global $params;

      $text = [ 
         "UI ".UI,
         "TIMEOUT ".TIMEOUT
      ];
      if($default = $this->getDefaultEntry()) array_push($text, "DEFAULT ".$default->label);
      if($params->shiftkey) array_push($text, "MENU SHIFTKEY");
      array_push($text, "\nMENU TITLE ".$this->titulo."\n");

      return implode("\n", $text);
   }

   protected function conclusion() {
      return "";
   }

   public function getType() {
      return "menu";
   }
}

class MenuCfg extends ModularCfg {

   protected function preambulo() {
      $text = ["MENU BEGIN ".$this->label."\n", "MENU TITLE ".$this->titulo."\n"];

      return implode("\n", array_map(function($line) { return $this->fprint($line); }, $text));
   }

   protected function conclusion() {
      $text = [
         INDENT."MENU SEPARATOR\n",
         INDENT."LABEL -",
         INDENT.INDENT."MENU LABEL ^Volver al menú principal",
         INDENT.INDENT."MENU EXIT\n",
         "MENU END"
      ];
      return "\n".implode("\n", array_map(function($line) { return $this->fprint($line); }, $text));
   }

   public function getType() {
      return "menu";
   }
}

class SectionCfg extends ModularCfg {

   protected function preambulo() {
      $text = [
         "LABEL ".$this->label,
         INDENT."MENU LABEL ".$this->titulo,
         INDENT."MENU DISABLED"
      ];

      return implode("\n", array_map(function ($line) { return $this->fprint($line); }, $text));
   }

   protected function conclusion() {
      return "";
   }

   public function getType() {
      return "section";
   }
}

/**
 * Entrada que falla siempre y sustituye a módulos
 * que no cumplen las exigencias mínimas.
 */
class FailModuleCfg extends BaseCfg {
   public function __construct($file, $label) {
      parent::__construct($file, $label);
      $this->fail = "# {$this->label}: {$this->file} no dispone de entry.php o es defectuoso";
   }

   public function getContents() {
      return implode("\n", $this->viewFail());
   }

   public function getType() {
      return "???";
   }
}

/**
 * Módulo programado por el usuario.
 */
function customCfg($file, $label) {

   # Si es un directorio, el script está dentro con nombre entry.php
   $script = $file.(is_dir($file)?"/entry.php":"");

   if(!file_exists($script)) return new FailModuleCfg($file, $label);

   include($script);

   # El script debe definir una clase ScriptCfg derivada de BaseCfg
   if(!is_subclass_of("ScriptCfg", "BaseCfg")) return new FailModuleCfg($file, $label);

   return new ScriptCfg($file, $label);
}

?>
