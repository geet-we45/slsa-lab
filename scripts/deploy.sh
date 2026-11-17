#!/usr/bin/env bash
# Deploy gate: only artifacts that pass the L3 policy may deploy.
# Usage: ./scripts/deploy.sh <binary>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

BIN="${1:-}"
[[ -n "${BIN}" && -f "${BIN}" ]] || die "Usage: $0 <binary>"

info "Deploy gate for $(basename "${BIN}") — requiring L3 policy..."
if "${SCRIPT_DIR}/verify/l3-policy.sh" "${BIN}"; then
  echo
  printf '%s🚀 DEPLOYED%s  %s\n' "${C_GREEN}" "${C_RESET}" "$(basename "${BIN}")"
  exit 0
fi
echo
printf '%s⛔ BLOCKED%s  %s (failed L3 policy)\n' "${C_RED}" "${C_RESET}" "$(basename "${BIN}")"
exit 1
