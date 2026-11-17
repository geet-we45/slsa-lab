#!/usr/bin/env bash
# Build two binaries (hello-a, hello-b). Exactly one is backdoored at random.
# Without provenance you cannot tell which. Use --reveal to show the answer.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd go

OUT_DIR="${LAB_ROOT}/out"
mkdir -p "${OUT_DIR}"
REVEAL=0
if [[ "${1:-}" == "--reveal" ]]; then
  REVEAL=1
fi

STATE="${OUT_DIR}/.level0-evil"
if [[ ! -f "${STATE}" ]]; then
  if (( RANDOM % 2 == 0 )); then
    echo a >"${STATE}"
  else
    echo b >"${STATE}"
  fi
fi
EVIL="$(tr -d '[:space:]' <"${STATE}")"

info "Building out/hello-a and out/hello-b (one is backdoored)..."
if [[ "${EVIL}" == "a" ]]; then
  build_go "${OUT_DIR}/hello-a" evil
  build_go "${OUT_DIR}/hello-b"
else
  build_go "${OUT_DIR}/hello-a"
  build_go "${OUT_DIR}/hello-b" evil
fi

chmod +x "${OUT_DIR}/hello-a" "${OUT_DIR}/hello-b"
ok "Built out/hello-a and out/hello-b"
echo
echo "Ship one of them. Without provenance, which would you choose?"
echo "  ./out/hello-a"
echo "  ./out/hello-b"
echo
echo "When ready:  ./scripts/level0/build.sh --reveal"

if [[ "${REVEAL}" -eq 1 ]]; then
  echo
  warn "Reveal: hello-${EVIL} was built with -tags evil (simulated backdoor)."
  echo "--- hello-a ---"
  "${OUT_DIR}/hello-a" || true
  echo "--- hello-b ---"
  "${OUT_DIR}/hello-b" || true
fi
