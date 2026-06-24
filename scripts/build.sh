#!/usr/bin/env bash
set -euo pipefail

# Build the snap locally. Run from the repository root.

cd "$(dirname "$0")/.."

echo "==> Cleaning previous build artifacts..."
snapcraft clean

echo "==> Packing snap..."
snapcraft pack --verbose

echo "==> Done. Built artifact:"
ls -lh ./*.snap
