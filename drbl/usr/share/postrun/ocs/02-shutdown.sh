#
# Apaga el servidor tras acabar la clonación multicast
#

. "`dirname $0`/../../prerun/ocs/utils.sh"
tempfiles=$(echo "$multifile" | sed -r 's:\{\{image\}\}:*:; s:\{\{iface\}\}:*:;')

if [ -n "$DELAY" ] && ! ls $tempfiles >/dev/null 2>&1; then
   [ $DELAY -ne 1 ] && DELAY=1
   sleep $((DELAY*60))
   sudo poweroff
fi
