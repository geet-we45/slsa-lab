#!/usr/bin/env bash
# Create a public learner repo from the org template, clone it, and print next steps.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

require_cmd gh git

REPO_NAME="${1:-my-slsa-lab}"
DEST="${2:-${HOME}/${REPO_NAME}}"

if [[ "${ORG}" == "YOUR_ORG" ]]; then
  die "ORG is still YOUR_ORG in lab.env — this template was not configured. Ask your instructor to republish the lab template."
fi

info "Checking gh authentication..."
if ! gh auth status >/dev/null 2>&1; then
  warn "Not logged in. Starting interactive login (HTTPS + repo scope)..."
  gh auth login
fi
ok "gh authenticated as $(gh api user -q .login)"

OWNER="$(gh api user -q .login)"
TARGET="${OWNER}/${REPO_NAME}"

if gh repo view "${TARGET}" >/dev/null 2>&1; then
  warn "Repo ${TARGET} already exists — cloning/using it."
else
  info "Creating public repo from template ${TEMPLATE_REPO}..."
  gh repo create "${REPO_NAME}" --public --template "${TEMPLATE_REPO}" --clone=false
  ok "Created ${TARGET}"
fi

if [[ -d "${DEST}/.git" ]]; then
  info "Destination ${DEST} already a git repo — skipping clone."
else
  mkdir -p "$(dirname "${DEST}")"
  gh repo clone "${TARGET}" "${DEST}"
  ok "Cloned into ${DEST}"
fi

cd "${DEST}"
export LEARNER_REPO="${TARGET}"
ok "LEARNER_REPO=${LEARNER_REPO}"
echo
echo "Next:"
echo "  cd ${DEST}"
echo "  ./scripts/release.sh v1.0.0    # starts the 4 GitHub Actions jobs in the background"
echo "  # while that runs (~2 min), continue with Step 1 (L0) in LAB_QUICKSTART.md"
