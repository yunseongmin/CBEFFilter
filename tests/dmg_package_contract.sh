#!/bin/sh
set -eu

bundle_path=${1:?usage: tests/dmg_package_contract.sh bundle pkg dmg preinstall}
package_path=${2:?usage: tests/dmg_package_contract.sh bundle pkg dmg preinstall}
dmg_path=${3:?usage: tests/dmg_package_contract.sh bundle pkg dmg preinstall}
preinstall=${4:?usage: tests/dmg_package_contract.sh bundle pkg dmg preinstall}
postinstall=$(dirname "$preinstall")/postinstall
temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/cbef-dmg-test.XXXXXX")
mount_point="$temporary_root/mount"
expanded_package="$temporary_root/expanded"
target_volume="$temporary_root/target"
clean_target_volume="$temporary_root/clean-target"
mounted=0

cleanup() {
    if [ "$mounted" -eq 1 ]; then
        /usr/bin/hdiutil detach -quiet "$mount_point" || true
    fi
    rm -rf "$temporary_root"
}
trap cleanup EXIT HUP INT TERM

test -d "$bundle_path"
test -f "$package_path"
test -f "$dmg_path"
/usr/bin/codesign --verify --deep --strict "$bundle_path"

/usr/sbin/pkgutil --payload-files "$package_path" | \
    /usr/bin/grep -q 'Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx'
/usr/sbin/pkgutil --expand "$package_path" "$expanded_package"
/usr/bin/grep -q 'identifier="com.cbef.filmeffects.installer"' "$expanded_package/PackageInfo"
/usr/bin/grep -q 'install-location="/"' "$expanded_package/PackageInfo"
test -x "$expanded_package/Scripts/preinstall"
test -x "$expanded_package/Scripts/install-policy.sh"
test -x "$expanded_package/Scripts/postinstall"

clean_installed="$clean_target_volume/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle"
"$preinstall" "$package_path" / "$clean_target_volume"
test ! -e "$clean_target_volume/Library/OFX/CBEFBackups/CBEFFilmEffects-v1-backup.ofx.bundle"
/usr/bin/ditto "$bundle_path" "$clean_installed"
"$postinstall" "$package_path" / "$clean_target_volume"

plugin_root="$target_volume/Library/OFX/Plugins"
installed="$plugin_root/CBEFFilmEffects.ofx.bundle"
backup="$target_volume/Library/OFX/CBEFBackups/CBEFFilmEffects-v1-backup.ofx.bundle"
mkdir -p "$plugin_root"
/usr/bin/ditto "$bundle_path" "$installed"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.9' "$installed/Contents/Info.plist"
"$preinstall" "$package_path" / "$target_volume"
test ! -e "$installed"
test -d "$backup"
/usr/bin/ditto "$bundle_path" "$installed"
"$postinstall" "$package_path" / "$target_volume"

mkdir -p "$mount_point"
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$mount_point" "$dmg_path"
mounted=1
test -f "$mount_point/$(basename "$package_path")"
test -f "$mount_point/README-Install.txt"
test -f "$mount_point/BUILD-MANIFEST.txt"
test -x "$mount_point/Uninstall CBEF Filter.command"
/usr/bin/grep -q 'Architecture: arm64 (Apple Silicon)' "$mount_point/BUILD-MANIFEST.txt"
/usr/bin/grep -q 'Bundle ID: com.cbef.filmeffects' "$mount_point/BUILD-MANIFEST.txt"
(
    cd "$mount_point"
    /usr/bin/shasum -a 256 -c SHA256SUMS.txt
)

echo "dmg_package_contract: PASS (native PKG payload + backup policy + mounted DMG contents)"
