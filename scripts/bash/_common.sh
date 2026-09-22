#!/usr/bin/env bash
# _common.sh - shared helpers for the Office Depot B2B Commerce (LWR) orchestration scripts.
#
# These scripts are ORCHESTRATION ONLY. They contain no business logic. Every piece of Apex
# lives as a deployable class in force-app/main/default/classes/ and is invoked here through a
# one-line static call, so there is no loose anonymous-Apex source anywhere in the repo.
#
# WHY THE POWERSHELL SHIM:
# On the Windows workstation this project is developed on, invoking `sf` directly from Git Bash
# fails with "'C:\Program' is not recognized" because the Node path contains a space and the
# sf.cmd shim does not quote it. Every sf invocation is therefore routed through powershell.exe.
# On Linux/macOS CI the shim is bypassed automatically (see sf_run below), so the same scripts
# satisfy the Constitution's CI gate without modification.
#
# Also note: `sf ... --json` output in this environment is prefixed by a CLI update warning.
# Use sf_json() when you need parseable JSON; it strips leading non-JSON lines.

set -euo pipefail

# Default is the clean B2B Commerce scratch org the storefront was actually built in.
# vscodeOrg is the contaminated Developer Edition sandbox and is READ-ONLY reference only.
TARGET_ORG="${TARGET_ORG:-officedepot-sc}"
STORE_NAME="${STORE_NAME:-Office Depot}"
SITE_TEMPLATE="${SITE_TEMPLATE:-Commerce Store (LWR)}"
URL_PATH_PREFIX="${URL_PATH_PREFIX:-officedepot}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASS_DIR="$PROJECT_ROOT/force-app/main/default/classes"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

# Run an sf command, transparently shimming through PowerShell on Windows.
sf_run() {
  if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OSTYPE:-}" == win32* ]]; then
    local joined=""
    for arg in "$@"; do
      joined+=" '${arg//\'/\'\'}'"
    done
    powershell.exe -NoProfile -Command "sf$joined"
  else
    sf "$@"
  fi
}

# Same as sf_run but strips the CLI update-warning preamble so the result is parseable JSON.
sf_json() {
  sf_run "$@" | sed -n '/^[[:space:]]*[{[]/,$p'
}

require_org() {
  log "Verifying target org: $TARGET_ORG"
  sf_run org display --target-org "$TARGET_ORG" >/dev/null 2>&1 \
    || die "Cannot reach org alias '$TARGET_ORG'. Run: sf org login web --alias $TARGET_ORG"
  ok "Org '$TARGET_ORG' reachable."
}

# Deploy the Apex classes. Must happen before any invoke_apex call.
deploy_classes() {
  log "Deploying Apex classes from force-app/main/default/classes"
  sf_run project deploy start --target-org "$TARGET_ORG" --source-dir "$CLASS_DIR" --wait 20
  ok "Apex classes deployed."
}

# Invoke a deployed class through a one-line static call.
# The invoking snippet is written to a throwaway file OUTSIDE the repo and deleted immediately,
# so no stray .apex source is ever added to source control.
# NEVER reorder these calls - BR-01 dependency order is absolute.
invoke_apex() {
  local call="$1"
  local tmp
  tmp="$(mktemp -t odinvoke.XXXXXX.apex 2>/dev/null || echo "${TMPDIR:-/tmp}/odinvoke.$$.apex")"
  printf '%s\n' "$call" > "$tmp"
  log "Invoking $call"
  local out status=0
  out="$(sf_run apex run --target-org "$TARGET_ORG" --file "$tmp" 2>&1)" || status=$?
  rm -f "$tmp"
  printf '%s\n' "$out"
  if [[ $status -ne 0 ]]; then
    die "$call failed. The dependency chain is halted; do NOT run later steps."
  fi
  if grep -qiE '\[FAIL\]|System\.[A-Za-z]*Exception|Commerce[A-Za-z]*Exception|Compile error' <<<"$out"; then
    die "$call reported a failure. The dependency chain is halted."
  fi
  ok "$call completed."
}

soql() {
  sf_run data query --target-org "$TARGET_ORG" --query "$1" --result-format csv
}

# Deploy org settings that the chain depends on. Currently CommunitiesSettings:
# enableOotbProfExtUserOpsEnable must be true or external buyer User creation fails with
# FIELD_INTEGRITY_EXCEPTION on ProfileId. This is metadata, NOT a manual Setup-UI step.
deploy_settings() {
  local dir="$PROJECT_ROOT/force-app/main/default/settings"
  [[ -d "$dir" ]] || return 0
  log "Deploying org settings"
  sf_run project deploy start --target-org "$TARGET_ORG" --source-dir "$dir" --wait 20
  ok "Settings deployed."
}

# Experience Cloud refuses to create a portal user whose account owner has no UserRole.
ensure_owner_role() {
  invoke_apex "List<UserRole> r = [SELECT Id FROM UserRole WHERE DeveloperName = 'OfficeDepotStoreOwner' LIMIT 1]; Id rid; if (r.isEmpty()) { UserRole n = new UserRole(Name = 'Office Depot Store Owner', DeveloperName = 'OfficeDepotStoreOwner'); insert n; rid = n.Id; } else { rid = r[0].Id; } User u = [SELECT Id, UserRoleId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]; if (u.UserRoleId == null) { u.UserRoleId = rid; update u; }"
}
