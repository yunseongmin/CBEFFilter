#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

make rebuild
sudo make install
echo "Restart DaVinci Resolve after installation so it rescans OpenFX bundles."
