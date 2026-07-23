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
PIN="$EX/platform.hcl"

SERVICES=("payment-service" "orders-db")
[ $# -gt 0 ] && [ "$1" != "--clean-only" ] && SERVICES=("$@")

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

# --- Platform version toggle -------------------------------------------------
# The developer stack files fetch the platform by `platform_version` in
# example/platform.hcl. A real tag (v1.1.0) is a git fetch — it only sees
# COMMITTED platform code, so iterating would need a commit+retag every edit.
# The special value "local-dev" sources the platform working tree directly.
#
# So this driver AUTO-TOGGLES: it runs the applies in "local-dev" (picks up your
# uncommitted platform/ edits, no commit needed), then does one extra pass
# pinned to the real tag to prove the versioned git-fetch path still resolves.
# The original pin is always restored on exit (even on failure/Ctrl-C).
ORIG_PIN="$(grep -E '^\s*platform_version\s*=' "$PIN")"
set_version() {
  # Replace the platform_version assignment line in place.
  sed -i -E "s|^(\s*platform_version\s*=).*|\1 \"$1\"|" "$PIN"
}
restore_pin() {
  [ -n "${ORIG_PIN:-}" ] && sed -i -E "s|^\s*platform_version\s*=.*|${ORIG_PIN}|" "$PIN"
}
trap restore_pin EXIT

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

# Apply against the platform WORKING TREE (picks up uncommitted platform/ edits).
log "Using platform_version = local-dev (working tree, no commit needed)"
set_version "local-dev"

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

# Versioned-fetch pass: prove the production path (a real git tag) still
# resolves — the working tree must be committed at that tag. This validates the
# git::file//...?ref=<tag> fetch, not just the local-dev shortcut.
VERSION_TAG="$(grep -E '^\s*platform_version\s*=' <<<"$ORIG_PIN" | sed -E 's|.*"([^"]+)".*|\1|')"
if [ -n "$VERSION_TAG" ] && [ "$VERSION_TAG" != "local-dev" ]; then
  log "Versioned-fetch check: re-plan $last pinned to '$VERSION_TAG' (git fetch)"
  if git -C "$ROOT" rev-parse -q --verify "refs/tags/$VERSION_TAG" >/dev/null; then
    set_version "$VERSION_TAG"
    ( cd "$EX/$last" && rm -rf .terragrunt-stack .terragrunt-cache )
    ver_out="$( cd "$EX/$last" && terragrunt stack run plan --non-interactive 2>&1 )"
    if grep -qE "No changes|Plan:" <<<"$ver_out"; then
      echo "  ok: platform fetched at tag '$VERSION_TAG'"
    else
      fail "versioned fetch failed for tag '$VERSION_TAG'"$'\n'"$ver_out"
    fi
    set_version "local-dev"
  else
    echo "  skip: tag '$VERSION_TAG' not found — commit + 'git tag $VERSION_TAG' to test the fetch path"
  fi
fi

log "SMOKE PASSED"
