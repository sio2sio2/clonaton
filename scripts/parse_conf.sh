CONFFILE=${CONFFILE:-"/etc/clonaton/clonaton.conf"}

parse_conf() {
   local IFS text pre="$1"
   texto=`sed -r '/^[_[:alnum:]]+\s*=/!d; y:'"'"':":; s:^(\S+)\s*=\s*(.*)$:'"${pre:+${pre}_}\1='\2':" "$CONFFILE"` || return 1
   eval $texto
}
