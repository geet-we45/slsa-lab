#!/usr/bin/env bash
# Clean local lab outputs so you can re-run from a known state.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

rm -rf "${LAB_ROOT}/out" "${LAB_ROOT}/artifacts"
mkdir -p "${LAB_ROOT}/out" "${LAB_ROOT}/artifacts"
ok "Cleared out/ and artifacts/"
