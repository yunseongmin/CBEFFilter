#!/bin/sh
set -eu

bundle_path=${1:?usage: scripts/package-dmg.sh path/to/CBEFFilmEffects.ofx.bundle [output-dir]}
output_dir=${2:-build/dist}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

if [ ! -d "$bundle_path" ]; then
    echo "OpenFX bundle not found: $bundle_path" >&2
    exit 2
fi

bundle_path=$(CDPATH= cd -- "$bundle_path" && pwd -P)
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd -P)
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$bundle_path/Contents/Info.plist")
package_name="CBEFFilter-$version.pkg"
dmg_name="CBEFFilter-$version.dmg"
package_path="$output_dir/$package_name"
dmg_path="$output_dir/$dmg_name"
binary_path="$bundle_path/Contents/MacOS/CBEFFilmEffects.ofx"
metallib_path="$bundle_path/Contents/Resources/CBEFFilmEffects.metallib"
temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/cbef-dmg.XXXXXX")
payload_root="$temporary_root/payload"
dmg_root="$temporary_root/dmg"

cleanup() {
    case "$temporary_root" in
        "${TMPDIR:-/tmp}"/cbef-dmg.*) rm -rf "$temporary_root" ;;
    esac
}
trap cleanup EXIT HUP INT TERM

/usr/bin/codesign --verify --deep --strict "$bundle_path"
mkdir -p "$payload_root/Library/OFX/Plugins" "$dmg_root"
/usr/bin/ditto "$bundle_path" "$payload_root/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle"

rm -f "$package_path" "$dmg_path"
/usr/bin/pkgbuild \
    --root "$payload_root" \
    --install-location / \
    --identifier com.cbef.filmeffects.installer \
    --version "$version" \
    --scripts "$project_root/packaging/pkg/scripts" \
    "$package_path"

/bin/cp "$package_path" "$dmg_root/$package_name"
/bin/cp "$project_root/packaging/README-Install.txt" "$dmg_root/README-Install.txt"
/bin/cp "$project_root/packaging/Uninstall CBEF Filter.command" "$dmg_root/Uninstall CBEF Filter.command"
/bin/chmod 755 "$dmg_root/Uninstall CBEF Filter.command"
bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle_path/Contents/Info.plist")
binary_hash=$(/usr/bin/shasum -a 256 "$binary_path" | /usr/bin/awk '{print $1}')
metallib_hash=$(/usr/bin/shasum -a 256 "$metallib_path" | /usr/bin/awk '{print $1}')
package_hash=$(/usr/bin/shasum -a 256 "$package_path" | /usr/bin/awk '{print $1}')
{
    printf '%s\n' "CBEF Filter Personal Restore"
    printf '%s\n' "Version: $version"
    printf '%s\n' "Bundle ID: $bundle_identifier"
    printf '%s\n' "Architecture: arm64 (Apple Silicon)"
    printf '%s\n' "Plugin binary SHA-256: $binary_hash"
    printf '%s\n' "Metal library SHA-256: $metallib_hash"
    printf '%s\n' "Installer package SHA-256: $package_hash"
} > "$dmg_root/BUILD-MANIFEST.txt"
(
    cd "$dmg_root"
    /usr/bin/shasum -a 256 "$package_name" > SHA256SUMS.txt
)

/usr/bin/hdiutil create \
    -volname "CBEF Filter Restore $version" \
    -srcfolder "$dmg_root" \
    -format UDZO \
    -ov \
    "$dmg_path"

printf '%s\n' "Created $package_path"
printf '%s\n' "Created $dmg_path"
