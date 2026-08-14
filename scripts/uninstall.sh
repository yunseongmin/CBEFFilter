#!/bin/sh
set -eu

plugin_root=${OFX_PLUGIN_DIR:-/Library/OFX/Plugins}
destination="$plugin_root/CBEFFilmEffects.ofx.bundle"

if [ "$(id -u)" -ne 0 ] && [ ! -w "$plugin_root" ]; then
    echo "Administrator permission is required to remove from $plugin_root." >&2
    echo "Run: sudo make uninstall" >&2
    exit 77
fi

case "$destination" in
    "$plugin_root"/CBEFFilmEffects.ofx.bundle) ;;
    *)
        echo "Refusing an unexpected OpenFX destination: $destination" >&2
        exit 2
        ;;
esac

if [ -e "$destination" ]; then
    rm -rf "$destination"
    echo "Removed $destination"
else
    echo "No CBEF Film Effects bundle is installed at $destination"
fi
