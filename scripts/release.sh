#!/usr/bin/env bash
# Tag, push, watch the Release workflow, download all artifacts into ./artifacts.
# Usage: ./scripts/release.sh [tag]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

require_cmd git gh

TAG="${1:-v1.0.0}"
LEARNER_REPO="$(detect_learner_repo)"
cd "${LAB_ROOT}"

if [[ "${ORG}" == "YOUR_ORG" ]]; then
  warn "ORG is YOUR_ORG — the l3 job will fail. Ask your instructor; the template should already have ORG set."
fi

# Ensure we have something to tag
if [[ -n "$(git status --porcelain)" ]]; then
  warn "Working tree has uncommitted changes; tagging current HEAD anyway."
fi

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  info "Tag ${TAG} already exists locally."
else
  git tag -a "${TAG}" -m "SLSA lab release ${TAG}"
  ok "Created annotated tag ${TAG}"
fi

info "Pushing tag ${TAG} to origin..."
git push origin "${TAG}"
ok "Pushed ${TAG}"

info "Waiting for workflow run on ${TAG}..."
# Give Actions a moment to register the run
sleep 3
RUN_ID="$(gh run list --repo "${LEARNER_REPO}" --workflow release.yml --limit 5 \
  --json databaseId,headBranch,status,event \
  --jq "[.[] | select(.headBranch==\"${TAG}\" or .event==\"push\")][0].databaseId // empty")"

if [[ -z "${RUN_ID}" ]]; then
  # Fallback: most recent run
  RUN_ID="$(gh run list --repo "${LEARNER_REPO}" --workflow release.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
fi

[[ -n "${RUN_ID}" ]] || die "No workflow run found. Check Actions tab / that workflows are enabled."

info "Watching run ${RUN_ID}..."
gh run watch "${RUN_ID}" --repo "${LEARNER_REPO}" --exit-status

rm -rf "${LAB_ROOT}/artifacts"
mkdir -p "${LAB_ROOT}/artifacts"
info "Downloading artifacts → artifacts/"
gh run download "${RUN_ID}" --repo "${LEARNER_REPO}" --dir "${LAB_ROOT}/artifacts"

# Make binaries executable
find "${LAB_ROOT}/artifacts" -type f ! -name '*.jsonl' ! -name '*.json' -exec chmod +x {} + 2>/dev/null || true

ok "Artifacts ready under artifacts/"
find "${LAB_ROOT}/artifacts" -type f | sort
