#!/bin/sh
set -eu

bundle_path=${1:?usage: tests/package_install_contract.sh path/to/CBEFFilmEffects.ofx.bundle}
installer=${2:?usage: tests/package_install_contract.sh bundle installer}
temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/cbef-package-test.XXXXXX")
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM

plugin_root="$temporary_root/OFX/Plugins"
backup_root="$temporary_root/OFX/CBEFBackups"
installed="$plugin_root/CBEFFilmEffects.ofx.bundle"
backup="$backup_root/CBEFFilmEffects-v1-backup.ofx.bundle"

codesign --verify --deep --strict "$bundle_path"
mkdir -p "$plugin_root"
ditto "$bundle_path" "$installed"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.9' "$installed/Contents/Info.plist"

legacy_active_backup="$plugin_root/CBEFFilmEffects-v1-backup.ofx.bundle"
ditto "$installed" "$legacy_active_backup"
rm -rf "$installed"

OFX_PLUGIN_DIR="$plugin_root" CBEF_BACKUP_DIR="$backup_root" "$installer" "$bundle_path"

test -d "$installed"
test -d "$backup"
ditto "$backup" "$legacy_active_backup"

OFX_PLUGIN_DIR="$plugin_root" CBEF_BACKUP_DIR="$backup_root" "$installer" "$bundle_path"

test -d "$backup_root/CBEFFilmEffects-v1-legacy-1.ofx.bundle"
test ! -e "$legacy_active_backup"
rm -rf "$installed" "$backup_root"
ditto "$bundle_path" "$installed"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.9' "$installed/Contents/Info.plist"

OFX_PLUGIN_DIR="$plugin_root" CBEF_BACKUP_DIR="$backup_root" "$installer" "$bundle_path"

test -d "$installed"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$installed/Contents/Info.plist")" = 2.0
test -d "$backup"
if find "$plugin_root" -mindepth 1 -maxdepth 1 -name '*backup*.ofx.bundle' -print | grep -q .; then
    echo "package_install_contract: backup bundle remained inside the active OFX scan root" >&2
    exit 1
fi

codesign --verify --deep --strict "$installed"
echo "package_install_contract: PASS (external v1 backup + final bundle signature)"
