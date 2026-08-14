#!/bin/sh
set -eu

/usr/bin/osascript <<'APPLESCRIPT'
do shell script "/bin/rm -rf '/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle'; /usr/sbin/pkgutil --forget com.cbef.filmeffects.installer >/dev/null 2>&1 || true" with administrator privileges
APPLESCRIPT

printf '%s\n' "CBEF Filter was removed. Restart DaVinci Resolve before checking the Effects list."
printf '%s' "Press Return to close this window."
read -r _unused
