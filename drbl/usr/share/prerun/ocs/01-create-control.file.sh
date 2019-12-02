#!/bin/sh

. "`dirname $0`/utils.sh"
control=`get_tempfile`

read_desc "$IMGDIR/$descfile"

printf '<?php
$ocs_live_run_params="%s";
$help="<\\t\\tClonación en multicast para %d clientes
<\\t\\tde la imagen %s";
?>\n' "$OPTS" "$NCLIENTS" "$nombre" > "$control"
