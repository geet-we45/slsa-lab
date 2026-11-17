#!/usr/bin/env bash
# Flip one byte in a copy of the binary to demonstrate post-build tampering detection.
# Usage: ./scripts/verify/tamper.sh <binary>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

BIN="${1:-}"
[[ -n "${BIN}" && -f "${BIN}" ]] || die "Usage: $0 <binary>"

OUT="${BIN}.tampered"
cp "${BIN}" "${OUT}"
OLD="$(sha256_file "${BIN}")"

# Flip a byte well into the file (seek past ELF/mach-O headers)
SIZE="$(wc -c <"${OUT}" | tr -d ' ')"
SEEK=1000
if [[ "${SIZE}" -le 1000 ]]; then
  SEEK=$((SIZE / 2))
fi

printf '\x00' | dd of="${OUT}" bs=1 seek="${SEEK}" count=1 conv=notrunc status=none 2>/dev/null \
  || printf '\x00' | dd of="${OUT}" bs=1 seek="${SEEK}" count=1 conv=notrunc 2>/dev/null

NEW="$(sha256_file "${OUT}")"
ok "Wrote ${OUT}"
echo "  old sha256: ${OLD}"
echo "  new sha256: ${NEW}"
echo "  flipped 1 byte at offset ${SEEK}"
