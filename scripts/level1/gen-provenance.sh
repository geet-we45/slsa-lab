#!/usr/bin/env bash
# Build hello-l1 and write unsigned in-toto / SLSA Provenance v1 JSON beside it.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd go jq git

OUT_DIR="${LAB_ROOT}/out"
mkdir -p "${OUT_DIR}"
BIN="${OUT_DIR}/hello-l1"
PROV="${OUT_DIR}/hello-l1.provenance.json"

info "Building ${BIN}..."
build_go "${BIN}"
chmod +x "${BIN}"

DIGEST="$(sha256_file "${BIN}")"
ORIGIN="$(git -C "${LAB_ROOT}" remote get-url origin 2>/dev/null || echo "local")"
REF="$(git -C "${LAB_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
COMMIT="$(git -C "${LAB_ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")"
GO_VER="$(go env GOVERSION 2>/dev/null || go version | awk '{print $3}')"
HOST="$(hostname -s 2>/dev/null || hostname)"
USER_NAME="$(id -un)"
STARTED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
INV_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "lab-$(date +%s)")"
FINISHED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg digest "${DIGEST}" \
  --arg origin "${ORIGIN}" \
  --arg ref "${REF}" \
  --arg commit "${COMMIT}" \
  --arg gover "${GO_VER}" \
  --arg builder "https://slsa-lab.example/ec2/${HOST}/${USER_NAME}" \
  --arg invid "${INV_ID}" \
  --arg started "${STARTED}" \
  --arg finished "${FINISHED}" \
  '{
    "_type": "https://in-toto.io/Statement/v1",
    "subject": [{ "name": "hello-l1", "digest": { "sha256": $digest } }],
    "predicateType": "https://slsa.dev/provenance/v1",
    "predicate": {
      "buildDefinition": {
        "buildType": "https://slsa-lab.example/local-go-build/v1",
        "externalParameters": { "repository": $origin, "ref": $ref },
        "internalParameters": { "goVersion": $gover },
        "resolvedDependencies": [{
          "uri": ("git+" + $origin + "@" + $ref),
          "digest": { "gitCommit": $commit }
        }]
      },
      "runDetails": {
        "builder": { "id": $builder },
        "metadata": {
          "invocationId": $invid,
          "startedOn": $started,
          "finishedOn": $finished
        }
      }
    }
  }' >"${PROV}"

ok "Wrote unsigned provenance → ${PROV}"
echo "  subject digest: ${DIGEST}"
echo "  builder.id:     https://slsa-lab.example/ec2/${HOST}/${USER_NAME}"
echo "  repository:     ${ORIGIN}"
echo "  commit:         ${COMMIT}"
