#!/bin/sh
set -eu

bundle_path=${1:?usage: scripts/install.sh path/to/CBEFFilmEffects.ofx.bundle}
plugin_root=${OFX_PLUGIN_DIR:-/Library/OFX/Plugins}
destination="$plugin_root/CBEFFilmEffects.ofx.bundle"
backup_root=${CBEF_BACKUP_DIR:-"$(dirname "$plugin_root")/CBEFBackups"}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
install_policy="$script_dir/../packaging/pkg/scripts/install-policy.sh"

if [ ! -d "$bundle_path" ]; then
    echo "OpenFX bundle not found: $bundle_path" >&2
    exit 2
fi

if [ "$(id -u)" -ne 0 ] && [ ! -w "$plugin_root" ]; then
    echo "Administrator permission is required to install into $plugin_root." >&2
    echo "Run: sudo make install" >&2
    exit 77
fi

"$install_policy" "$plugin_root" "$backup_root"
ditto "$bundle_path" "$destination"
echo "Installed CBEF Film Effects to $destination"
