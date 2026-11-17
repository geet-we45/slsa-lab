#!/usr/bin/env bash
# Evaluate all known lab artifacts and print the Step-5 scoreboard.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"

require_cmd jq

OUT="${LAB_ROOT}/out"
ART="${LAB_ROOT}/artifacts"

# Resolve artifact paths (gh run download puts files under artifacts/<name>/)
find_bin() {
  local name="$1"
  local candidates=(
    "${ART}/${name}/${name}"
    "${ART}/${name}"
    "${OUT}/${name}"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -f "${c}" ]]; then
      printf '%s\n' "${c}"
      return 0
    fi
  done
  return 1
}

mark() {
  # $1=pass|fail|na  → symbol
  case "$1" in
    pass) printf '%s✅%s' "${C_GREEN}" "${C_RESET}" ;;
    fail) printf '%s❌%s' "${C_RED}" "${C_RESET}" ;;
    na)   printf 'n/a' ;;
    bang) printf '%s✅ (!)%s' "${C_YELLOW}" "${C_RESET}" ;;
    star) printf '%s❌ *%s' "${C_YELLOW}" "${C_RESET}" ;;
    *)    printf '?' ;;
  esac
}

# Quiet check helpers (no colored spam)
check_l1() {
  local bin="$1"
  local prov="${bin}.provenance.json"
  [[ -f "${bin}" && -f "${prov}" ]] || return 2
  local actual claimed
  actual="$(sha256_file "${bin}")"
  claimed="$(jq -r '.subject[0].digest.sha256' "${prov}")"
  [[ "${actual}" == "${claimed}" ]]
}

check_l2() {
  local bin="$1"
  [[ -f "${bin}" ]] || return 2
  LEARNER_REPO="$(detect_learner_repo)"
  set +e
  attest_verify "${bin}" \
    --signer-workflow "${LEARNER_REPO}/.github/workflows/release.yml" \
    --deny-self-hosted-runners >/dev/null 2>&1
  local rc=$?
  set -e
  return "${rc}"
}

check_l3() {
  local bin="$1"
  [[ -f "${bin}" ]] || return 2
  LEARNER_REPO="$(detect_learner_repo)"
  set +e
  attest_verify "${bin}" \
    --signer-workflow "${BUILDER_WORKFLOW}" \
    --deny-self-hosted-runners >/dev/null 2>&1
  local rc=$?
  set -e
  return "${rc}"
}

# Collect rows: label|path|l1_mode|l2_mode|l3_mode|notes
# modes: auto|na|force_bang_l2|force_star_l2
declare -a ROWS=()

# Level 0 evil binary
if [[ -f "${OUT}/.level0-evil" ]]; then
  EVIL="$(tr -d '[:space:]' <"${OUT}/.level0-evil")"
  if [[ -f "${OUT}/hello-${EVIL}" ]]; then
    ROWS+=("out/hello-${EVIL} (evil)|${OUT}/hello-${EVIL}|na|auto|auto|")
  fi
elif [[ -f "${OUT}/hello-a" ]]; then
  # Unknown which is evil — show both as L0
  ROWS+=("out/hello-a|${OUT}/hello-a|na|auto|auto|")
  ROWS+=("out/hello-b|${OUT}/hello-b|na|auto|auto|")
fi

add_if() {
  local label="$1" name="$2" l1m="$3" l2m="$4" l3m="$5" note="${6:-}"
  local p
  if p="$(find_bin "${name}")"; then
    ROWS+=("${label}|${p}|${l1m}|${l2m}|${l3m}|${note}")
  elif [[ -f "${OUT}/${name}" ]]; then
    ROWS+=("${label}|${OUT}/${name}|${l1m}|${l2m}|${l3m}|${note}")
  fi
}

add_if "out/hello-l1" "hello-l1" auto auto auto ""
add_if "out/hello-l1-forged" "hello-l1-forged" bang_l1 auto auto "forged"

# Prefer artifact paths for release outputs
add_if "hello-l2" "hello-l2" na auto auto ""
if p="$(find_bin hello-l2)"; then
  if [[ -f "${p}.tampered" ]]; then
    ROWS+=("hello-l2.tampered|${p}.tampered|na|auto|auto|")
  fi
fi
add_if "hello-l2-pwned" "hello-l2-pwned" na bang_l2 auto "pwned"
add_if "hello-l3" "hello-l3" na star_l2 auto ""
add_if "hello-l3-forged" "hello-l3-forged" na bang_l2 auto "forge"

printf '\n%sSLSA Lab Scoreboard%s\n' "${C_BOLD}" "${C_RESET}"
printf '%-24s %-10s %-12s %-10s %s\n' "artifact" "L1-check" "L2-policy" "L3-policy" "deploy"
printf '%-24s %-10s %-12s %-10s %s\n' "------------------------" "----------" "------------" "----------" "--------"

NOTES=()

for row in "${ROWS[@]}"; do
  IFS='|' read -r label path l1m l2m l3m note <<<"${row}"

  # L1
  l1s="na"
  if [[ "${l1m}" == "na" ]]; then
    l1s="na"
  elif [[ "${l1m}" == "bang_l1" ]]; then
    if check_l1 "${path}"; then l1s="bang"; else l1s="fail"; fi
  else
    if [[ -f "${path}.provenance.json" ]]; then
      if check_l1 "${path}"; then l1s="pass"; else l1s="fail"; fi
    else
      l1s="na"
    fi
  fi

  # L2
  l2s="fail"
  if [[ "${l2m}" == "na" ]]; then
    l2s="na"
  else
    if check_l2 "${path}"; then
      if [[ "${l2m}" == "bang_l2" ]]; then l2s="bang"
      elif [[ "${l2m}" == "star_l2" ]]; then l2s="pass" # unexpected pass
      else l2s="pass"; fi
    else
      if [[ "${l2m}" == "star_l2" ]]; then l2s="star"
      else l2s="fail"; fi
    fi
  fi

  # L3
  l3s="fail"
  if check_l3 "${path}"; then l3s="pass"; else l3s="fail"; fi

  # Deploy
  if [[ "${l3s}" == "pass" ]]; then
    dep="${C_GREEN}DEPLOYED${C_RESET}"
  else
    dep="${C_RED}BLOCKED${C_RESET}"
  fi

  printf '%-24s %-10s %-12s %-10s %b\n' \
    "${label}" "$(mark "${l1s}")" "$(mark "${l2s}")" "$(mark "${l3s}")" "${dep}"

  case "${note}" in
    forged) NOTES+=("(!) out/hello-l1-forged: unsigned provenance was edited to match an evil binary — L1-check still passes.") ;;
    pwned)  NOTES+=("(!) hello-l2-pwned: platform signed a binary swapped mid-build by fancy-lint — L2-policy still passes.") ;;
    forge)  NOTES+=("(!) hello-l3-forged: signed by the learner release.yml (L2 identity), not the isolated builder — L3-policy fails.") ;;
  esac
done

if [[ "${#ROWS[@]}" -eq 0 ]]; then
  warn "No artifacts found under out/ or artifacts/. Run earlier lab steps first."
fi

echo
if [[ "${#NOTES[@]}" -gt 0 ]]; then
  # unique notes
  printf '%s\n' "${NOTES[@]}" | awk '!seen[$0]++'
fi
echo "* hello-l3 fails the L2 policy only because that policy expects the learner's release.yml as signer — policies encode expectations."
echo
ok "Scoreboard complete. Only hello-l3 should DEPLOY."
