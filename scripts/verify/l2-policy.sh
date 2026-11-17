#!/usr/bin/env bash
# L2 policy: provenance signed by THIS learner repo's release.yml on GitHub-hosted runners.
# Usage: ./scripts/verify/l2-policy.sh <binary>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd gh

BIN="${1:-}"
[[ -n "${BIN}" && -f "${BIN}" ]] || die "Usage: $0 <binary>"

LEARNER_REPO="$(detect_learner_repo)"
SIGNER="${LEARNER_REPO}/.github/workflows/release.yml"

info "L2 policy: repo=${LEARNER_REPO} signer-workflow=${SIGNER}"
if [[ -f "${BIN}.bundle.jsonl" ]]; then
  info "Using offline bundle ${BIN}.bundle.jsonl"
fi

set +e
OUT="$(attest_verify "${BIN}" \
  --signer-workflow "${SIGNER}" \
  --deny-self-hosted-runners 2>&1)"
RC=$?
set -e
printf '%s\n' "${OUT}"

if [[ ${RC} -eq 0 ]]; then
  ok "L2-policy: verification succeeded for $(basename "${BIN}")"
  exit 0
fi
fail "L2-policy: verification failed for $(basename "${BIN}")"
exit 1
