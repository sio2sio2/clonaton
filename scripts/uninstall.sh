#!/bin/bash

BINDIR=$(dirname "$0")
. "$BINDIR/parse_conf.sh"

parse_conf x || exit 1

rm -rf "$x_appdir" "$x_tftpdir"/{bios,efi{32,64},ssoo}
rmdir -p "$x_tftpdir"
[ -d "$x_imgdir" ] && [ -z "`ls -A "$x_imgdir"`" ] && rmdir "$x_imgdir"

# Eliminamos la entrada para el directorio images
sed -ri '/^# clonaton$/{N;d}' /etc/exports
