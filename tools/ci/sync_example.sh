#!/usr/bin/env bash
# Copies the framework addon (addons/npcf) and the vendored gdUnit4 into examples/cakeworks/addons/.
# Each example owns a copy so it can be opened on its own. Idempotent: the two folders are replaced.
set -euo pipefail
cd "$(dirname "$0")/../.."
rm -rf examples/cakeworks/addons/npcf examples/cakeworks/addons/gdUnit4
mkdir -p examples/cakeworks/addons
cp -r addons/npcf addons/gdUnit4 examples/cakeworks/addons/
