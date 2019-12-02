<?php

class ParamsObject extends ArrayObject {

   private static $NOTYPE = "desc.";
   private static $NOROOM = "?";

   public function __construct($shiftkey, $array = null) {
      parent::__construct($array??$_GET);

      $this->parseMAC();
      $this->setLAN();

      if(array_key_exists("shiftkey", $this)) {
         $this->shiftkey = $this["shiftkey"] != 0;
         unset($this["shiftkey"]);
      }
      else $this->shiftkey = $shiftkey;
   }

   public function __call($func, $argv) {
      if (!is_callable($func) || substr($func, 0, 6) !== 'array_') {
         throw new BadMethodCallException(__CLASS__.'->'.$func);
      }
      else return call_user_func_array($func, array_merge(array($this->getArrayCopy()), $argv));
   }

   /**
    * Analiza la MAC proporcionada para determinar el tipo de máquina
    */
   private function parseMAC() {
      # La MAC nos llega con "-", no con ":"
      $this['mac'] = str_replace("-", ":", $this['mac']);
      $this['localboot'] = -1;
      $this['type'] = null;
      $this['submac'] = "";
      $this['desc'] = "";

      foreach(explode("\n", file_get_contents(abspath(HOSTS))) as $line) {
         if(!preg_match("/^((?:(?:[a-f0-9]{2}|\*):){5}(?:[a-f0-9]{2}|\*)),\s*(\w+)\s+#([^,]*)\s*(?:,\s*(0|-1))?\s*$/i", $line, $matches)) continue;
         list($_, $pmac, $ptype, $pdesc, $plocalboot) = $matches;
         $pos = strpos($pmac, "*");
         if($pos) $pmac = substr($pmac, 0, $pos-1);
         if(strpos(strtoupper($this['mac']), strtoupper($pmac)) === false or strlen($this['submac']) > strlen($pmac)) continue;
         $this['type'] = $ptype;
         $this['submac'] = $pmac;
         $this['desc'] = $pdesc??$this['type'];
         $this['localboot'] = $plocalboot == "0"?"0":"-1";
      }
   }

   /**
    * Determina el nombre del aula en la que se encuentra el cliente.
    */
   private function setLAN() {
      $ip = $_SERVER['REMOTE_ADDR'];

      foreach(explode("\n", file_get_contents(abspath(NETWORKS))) as $line) {
         list($name, $cidr, $iface) = array_map("trim", explode(",", $line));
         if(ipMatch($ip, $cidr)) {
            $this['iface'] = $iface;
            $this['room'] = $name;
	    return;
         }
      }
      $this['iface'] = null;
      $this['room'] = null;
   }

   public function get($key) {
      switch($key) {
         case "type":
            return $this['type']??self::$NOTYPE;
         case "room":
            return $this['room']??self::$NOROOM;
         default:
            return $this[$key];
      }
   }
}
?>
