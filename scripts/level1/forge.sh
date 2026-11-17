#!/usr/bin/env bash
# Build an evil binary and forge L1 provenance so the digest still "checks out".
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd go jq

OUT_DIR="${LAB_ROOT}/out"
mkdir -p "${OUT_DIR}"
BIN="${OUT_DIR}/hello-l1-forged"
PROV="${OUT_DIR}/hello-l1-forged.provenance.json"
SRC_PROV="${OUT_DIR}/hello-l1.provenance.json"

info "Building evil binary ${BIN}..."
build_go "${BIN}" evil
chmod +x "${BIN}"
DIGEST="$(sha256_file "${BIN}")"

if [[ -f "${SRC_PROV}" ]]; then
  jq --arg d "${DIGEST}" \
    '.subject[0].name = "hello-l1-forged" | .subject[0].digest.sha256 = $d' \
    "${SRC_PROV}" >"${PROV}"
else
  warn "No hello-l1.provenance.json yet — generating a forged statement from scratch."
  ORIGIN="$(git -C "${LAB_ROOT}" remote get-url origin 2>/dev/null || echo "local")"
  REF="$(git -C "${LAB_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
  COMMIT="$(git -C "${LAB_ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")"
  jq -n --arg d "${DIGEST}" --arg origin "${ORIGIN}" --arg ref "${REF}" --arg commit "${COMMIT}" \
    '{
      "_type": "https://in-toto.io/Statement/v1",
      "subject": [{ "name": "hello-l1-forged", "digest": { "sha256": $d } }],
      "predicateType": "https://slsa.dev/provenance/v1",
      "predicate": {
        "buildDefinition": {
          "buildType": "https://slsa-lab.example/local-go-build/v1",
          "externalParameters": { "repository": $origin, "ref": $ref },
          "internalParameters": { "goVersion": "forged" },
          "resolvedDependencies": [{
            "uri": ("git+" + $origin + "@" + $ref),
            "digest": { "gitCommit": $commit }
          }]
        },
        "runDetails": {
          "builder": { "id": "https://slsa-lab.example/ec2/trusted-ci/bot" },
          "metadata": {
            "invocationId": "forged",
            "startedOn": "1970-01-01T00:00:00Z",
            "finishedOn": "1970-01-01T00:00:01Z"
          }
        }
      }
    }' >"${PROV}"
fi

ok "Forged provenance → ${PROV}"
echo "  forged digest now matches evil binary: ${DIGEST}"
warn "L1 check will pass — the record is unsigned and editable."
