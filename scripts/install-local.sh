#!/usr/bin/env bash
set -euo pipefail

# Install the locally built snap in strict mode. Run from the repository root.

cd "$(dirname "$0")/.."

SNAP_NAME="rinconjr-avalonia-xaml-playground"
SNAP_FILE=$(ls -t ./*.snap | head -n 1)

if [[ -z "${SNAP_FILE}" ]]; then
    echo "No .snap file found. Run scripts/build.sh first." >&2
    exit 1
fi

echo "==> Installing ${SNAP_FILE}..."
sudo snap install "${SNAP_FILE}" --dangerous

echo "==> Checking connections..."
snap connections "${SNAP_NAME}"

echo "==> Launch the app with: ${SNAP_NAME}"
