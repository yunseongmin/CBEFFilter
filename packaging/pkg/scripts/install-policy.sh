#!/bin/sh
set -eu

plugin_root=${1:?usage: install-policy.sh plugin-root backup-root}
backup_root=${2:?usage: install-policy.sh plugin-root backup-root}
destination="$plugin_root/CBEFFilmEffects.ofx.bundle"
v1_backup="$backup_root/CBEFFilmEffects-v1-backup.ofx.bundle"
legacy_active_backup="$plugin_root/CBEFFilmEffects-v1-backup.ofx.bundle"

mkdir -p "$plugin_root"
mkdir -p "$backup_root"

plugin_root_resolved=$(cd "$plugin_root" && pwd -P)
backup_root_resolved=$(cd "$backup_root" && pwd -P)
case "$backup_root_resolved/" in
    "$plugin_root_resolved"/*)
        echo "Refusing to keep a backup inside the active OpenFX scan root: $backup_root" >&2
        exit 2
        ;;
esac

case "$destination" in
    "$plugin_root"/CBEFFilmEffects.ofx.bundle) ;;
    *)
        echo "Refusing an unexpected OpenFX destination: $destination" >&2
        exit 2
        ;;
esac

if [ -e "$legacy_active_backup" ]; then
    legacy_backup_destination=$v1_backup
    legacy_backup_index=1
    while [ -e "$legacy_backup_destination" ]; do
        legacy_backup_destination="$backup_root/CBEFFilmEffects-v1-legacy-$legacy_backup_index.ofx.bundle"
        legacy_backup_index=$((legacy_backup_index + 1))
    done
    mv "$legacy_active_backup" "$legacy_backup_destination"
    echo "Moved the legacy v1 backup outside the active OpenFX scan root to $legacy_backup_destination"
fi

if [ -d "$destination" ]; then
    installed_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
        "$destination/Contents/Info.plist" 2>/dev/null || printf 'unknown')
    case "$installed_version" in
        1.*)
            if [ -e "$v1_backup" ]; then
                echo "Refusing to overwrite the existing v1 backup: $v1_backup" >&2
                exit 73
            fi
            mv "$destination" "$v1_backup"
            echo "Backed up CBEF Film Effects v1 to $v1_backup"
            ;;
        *) rm -rf "$destination" ;;
    esac
fi
