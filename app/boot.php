<?php

require_once("lib/sysmenu.php");

header("Content-Type: text/plain");
echo encoder(loadCfg(abspath(\ITEMSDIR))->getContents());

?>

