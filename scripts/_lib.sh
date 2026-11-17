#!/usr/bin/env bash
# Shared helpers for SLSA lab scripts. Source this; do not execute.
# shellcheck shell=bash

set -euo pipefail

_SLSA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "${_SLSA_LIB_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${LAB_ROOT}/lab.env"

# Expand nested ${ORG} in BUILDER_* after sourcing lab.env
BUILDER_REPO="${ORG}/slsa-lab-builder"
TEMPLATE_REPO="${ORG}/slsa-lab"
BUILDER_WORKFLOW="${BUILDER_REPO}/.github/workflows/build.yml"
BUILDER_REF="${BUILDER_REF:-v1}"

if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'
  C_RED=$'\033[31m'
  C_YELLOW=$'\033[33m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_GREEN='' C_RED='' C_YELLOW='' C_BOLD='' C_DIM='' C_RESET=''
fi

ok()   { printf '%s✅%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
fail() { printf '%s❌%s %s\n' "${C_RED}" "${C_RESET}" "$*"; }
warn() { printf '%s⚠%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*"; }
info() { printf '%sℹ%s %s\n' "${C_DIM}" "${C_RESET}" "$*"; }

die() {
  fail "$*" >&2
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "${c}" >/dev/null 2>&1 || die "Missing required command: ${c}"
  done
}

# Normalize a git remote URL to owner/repo.
normalize_repo() {
  local url="$1"
  url="${url%.git}"
  if [[ "${url}" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  if [[ "${url}" =~ ^([^/]+)/([^/]+)$ ]]; then
    printf '%s\n' "${url}"
    return 0
  fi
  return 1
}

detect_learner_repo() {
  if [[ -n "${LEARNER_REPO:-}" ]]; then
    printf '%s\n' "${LEARNER_REPO}"
    return 0
  fi
  local url
  if url="$(git -C "${LAB_ROOT}" remote get-url origin 2>/dev/null)"; then
    if normalize_repo "${url}"; then
      return 0
    fi
  fi
  die "Cannot detect LEARNER_REPO. Set LEARNER_REPO=owner/repo or run from a clone with origin set."
}

# Lazily resolved by scripts that need it (avoid failing when sourcing outside a clone).
LEARNER_REPO="${LEARNER_REPO:-}"

go_build_flags() {
  local version="${1:-dev}"
  printf '%s' "-trimpath -ldflags \"-s -w -X main.version=${version}\""
}

build_go() {
  # usage: build_go <out> [extra-tags...]
  # go.mod lives in app/; use go build -C (Go 1.20+) from the lab root.
  local out="$1"
  shift
  local version
  version="$(git -C "${LAB_ROOT}" describe --tags --exact-match 2>/dev/null || git -C "${LAB_ROOT}" rev-parse --short HEAD 2>/dev/null || echo dev)"
  mkdir -p "$(dirname "${out}")"
  # Resolve out to an absolute path so -C app does not break relative -o
  if [[ "${out}" != /* ]]; then
    out="$(cd "$(dirname "${out}")" && pwd)/$(basename "${out}")"
  fi
  if [[ $# -gt 0 ]]; then
    CGO_ENABLED=0 go build -C "${LAB_ROOT}/app" -tags "$*" -trimpath \
      -ldflags "-s -w -X main.version=${version}" \
      -o "${out}" .
  else
    CGO_ENABLED=0 go build -C "${LAB_ROOT}/app" -trimpath \
      -ldflags "-s -w -X main.version=${version}" \
      -o "${out}" .
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

bundle_flag_for() {
  local bin="$1"
  local bundle="${bin}.bundle.jsonl"
  if [[ -f "${bundle}" ]]; then
    printf -- '--bundle %q' "${bundle}"
  fi
}

# Run gh attestation verify; auto-add --bundle when present.
# Extra args after the binary are appended (e.g. --signer-workflow ...).
attest_verify() {
  local bin="$1"
  shift
  local -a cmd=(gh attestation verify "${bin}" --repo "${LEARNER_REPO}")
  if [[ -f "${bin}.bundle.jsonl" ]]; then
    cmd+=(--bundle "${bin}.bundle.jsonl")
  fi
  cmd+=("$@")
  "${cmd[@]}"
}
