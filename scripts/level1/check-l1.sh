#!/usr/bin/env bash
# Compare binary sha256 to the subject digest in an unsigned provenance file.
# Usage: ./scripts/level1/check-l1.sh [binary] [provenance.json]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd jq

BIN="${1:-${LAB_ROOT}/out/hello-l1}"
PROV="${2:-}"
if [[ -z "${PROV}" ]]; then
  if [[ -f "${BIN}.provenance.json" ]]; then
    PROV="${BIN}.provenance.json"
  else
    PROV="${LAB_ROOT}/out/$(basename "${BIN}").provenance.json"
  fi
fi

[[ -f "${BIN}" ]] || die "Binary not found: ${BIN}"
[[ -f "${PROV}" ]] || die "Provenance not found: ${PROV}"

ACTUAL="$(sha256_file "${BIN}")"
CLAIMED="$(jq -r '.subject[0].digest.sha256' "${PROV}")"

echo "binary:     ${BIN}"
echo "provenance: ${PROV}"
echo "actual:     ${ACTUAL}"
echo "claimed:    ${CLAIMED}"

if [[ "${ACTUAL}" == "${CLAIMED}" ]]; then
  ok "L1-check: digest matches subject"
  exit 0
fi
fail "L1-check: digest mismatch"
exit 1
