#!/usr/bin/env bash
# Smoke driver for the Terragrunt Platform PoC.
#
# Drives the "app" (terragrunt + terraform applying mock-cloud stacks) end to
# end from a clean state, then asserts the simulated resource files were
# written with the expected content. No cloud creds — modules only write local
# files under example/deployed_resources/.
#
# Usage:
#   .claude/skills/run-terragrunt-poc/smoke.sh              # apply all services
#   .claude/skills/run-terragrunt-poc/smoke.sh payment-service
#   .claude/skills/run-terragrunt-poc/smoke.sh --clean-only # just wipe artifacts
#
# Exit 0 = every unit applied and every expected output file matched.
set -euo pipefail

# Repo root = two dirs up from this skill (.../.claude/skills/run-terragrunt-poc/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EX="$ROOT/example"
DEPLOYED="$EX/deployed_resources"

SERVICES=("payment-service" "orders-db")
[ $# -gt 0 ] && [ "$1" != "--clean-only" ] && SERVICES=("$@")

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

clean() {
  log "Cleaning generated artifacts"
  for svc in "${SERVICES[@]}"; do
    rm -rf "$EX/$svc/.terragrunt-stack" "$EX/$svc/.terragrunt-cache"
  done
  rm -f "$DEPLOYED"/*.txt
  echo "cleaned: .terragrunt-stack/, .terragrunt-cache/, deployed_resources/*.txt"
}

clean
[ "${1:-}" = "--clean-only" ] && exit 0

command -v terragrunt >/dev/null || fail "terragrunt not on PATH"
command -v terraform  >/dev/null || fail "terraform not on PATH"

for svc in "${SERVICES[@]}"; do
  log "Applying stack: $svc"
  ( cd "$EX/$svc" && terragrunt stack run apply --non-interactive ) \
    || fail "apply failed for $svc"
done

# Assert the simulated "provisioned" files exist and look right.
log "Verifying deployed_resources/"
assert_file() {
  local f="$DEPLOYED/$1" needle="$2"
  [ -f "$f" ] || fail "missing output file: $f"
  grep -q "$needle" "$f" || fail "$f missing expected text: $needle"
  echo "  ok: $1 (contains \"$needle\")"
}

for svc in "${SERVICES[@]}"; do
  case "$svc" in
    payment-service)
      assert_file "payment-service-db_config.txt"    "Engine: POSTGRES_15"
      assert_file "payment-service-cache_config.txt"  "Engine: REDIS_7"
      ;;
    orders-db)
      assert_file "orders-service-db_config.txt"      "POSTGRES_"
      ;;
  esac
done

# Idempotency: a re-plan on the last service should report no changes.
# Capture to a var first — piping straight into `grep -q` can SIGPIPE
# terragrunt and trip `pipefail` even on a clean plan.
last="${SERVICES[${#SERVICES[@]}-1]}"
log "Idempotency check: re-plan $last (expect 'No changes')"
plan_out="$( cd "$EX/$last" && terragrunt stack run plan --non-interactive 2>&1 )"
if grep -q "No changes" <<<"$plan_out"; then
  echo "  ok: no drift after apply"
else
  fail "re-plan reported drift for $last"
fi

log "SMOKE PASSED"
