#!/usr/bin/env bash
# Print signer identity fields from a verified attestation (JSON).
# Usage: ./scripts/verify/inspect.sh <binary>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../_lib.sh"

require_cmd gh jq

BIN="${1:-}"
[[ -n "${BIN}" && -f "${BIN}" ]] || die "Usage: $0 <binary>"

LEARNER_REPO="$(detect_learner_repo)"

set +e
JSON="$(attest_verify "${BIN}" --format json 2>/dev/null)"
RC=$?
set -e
if [[ ${RC} -ne 0 || -z "${JSON}" ]]; then
  die "Could not verify/load attestation for ${BIN}. Need network or a .bundle.jsonl beside the binary (gh may still require auth even with --bundle)."
fi

echo "=== Signer identity for $(basename "${BIN}") ==="

# Prefer certificate extensions (Fulcio OIDs); fall back to statement.predicate fields.
printf '%s\n' "${JSON}" | jq -r '
  def ext($oid):
    .[0].verificationResult.signature.certificate.extensions[$oid] // empty;
  def get($paths):
    ($paths | map(select(. != null and . != "")) | .[0] // "n/a");

  .[0].verificationResult as $v |
  ($v.signature.certificate // {}) as $c |
  ($c.extensions // {}) as $e |

  "repository:       " + get([
      $e["1.3.6.1.4.1.57264.1.5"],
      $e["1.3.6.1.4.1.57264.1.13"],
      $c.sourceRepositoryURI,
      $v.statement.predicate.buildDefinition.externalParameters.github.repository
    ]) ,
  "ref:              " + get([
      $e["1.3.6.1.4.1.57264.1.14"],
      $e["1.3.6.1.4.1.57264.1.6"],
      $c.sourceRepositoryRef,
      $v.statement.predicate.buildDefinition.externalParameters.github.ref
    ]) ,
  "builder.id:       " + get([
      $v.statement.predicate.runDetails.builder.id,
      $e["1.3.6.1.4.1.57264.1.1"],
      $e["1.3.6.1.4.1.57264.1.8"]
    ]) ,
  "signer workflow:  " + get([
      $e["1.3.6.1.4.1.57264.1.9"],
      $e["1.3.6.1.4.1.57264.1.12"],
      $c.subjectAlternativeName,
      $v.statement.predicate.buildDefinition.internalParameters.github.job_workflow_ref
    ]) ,
  "runner env:       " + get([
      $e["1.3.6.1.4.1.57264.1.11"],
      $e["1.3.6.1.4.1.57264.1.10"],
      $v.statement.predicate.buildDefinition.internalParameters.github.runner_environment
    ]) ,
  "subject.name:     " + ($v.statement.subject[0].name // "n/a") ,
  "subject.sha256:   " + ($v.statement.subject[0].digest.sha256 // "n/a")
'

info "Tip: compare signer workflow — L3 artifacts show geet-we45/slsa-lab-builder/.../build.yml; L2 show LEARNER/.../release.yml"
