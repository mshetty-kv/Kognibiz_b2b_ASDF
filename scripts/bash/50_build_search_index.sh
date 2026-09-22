#!/usr/bin/env bash
# 50_build_search_index.sh - Canonical chain step 10: build the product search index.
# Traces to: FR-04 / US-04, EC-01.
#
# BOUNDARY STEP - CLASS 3 (requires a direct API call; no metadata, no SOQL/DML path).
# Empirically established against org 00DgL00000L7NwjUAF on 2026-09-21:
#   - There is NO ProductSearchIndex sObject in this org, so the index cannot be created
#     with `sf data create record` or Apex DML.
#   - `sf org list metadata-types` exposes no search-index metadata type, so it cannot be
#     deployed either.
#   - The Commerce Webstore Management REST resource DOES work. A live GET against a sibling
#     store returned a real index document:
#       GET /services/data/v67.0/commerce/management/webstores/0ZEgL0000008e0HWAQ/search/indexes
#       -> {"indexes":[{"indexStatus":"Completed","indexBuildType":"Full","indexUsage":"Live",
#           "creationType":"Manual","completionDate":"2026-07-14T06:39:38.000Z", ...}]}
# POSTing to the same resource triggers a build. That is the automation path used below.
#
# Until the index reaches indexStatus "Completed" the PLP, search page and category pages
# return nothing, even though the catalog, entitlement and pricing are all correct.
#
# THIS SCRIPT MODIFIES THE ORG. Do not run it without explicit approval.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Resolving the WebStore Id for '$STORE_NAME'"
STORE_ID="$(soql "SELECT Id FROM WebStore WHERE Name = '$STORE_NAME'" | tail -n +2 | tr -d '\r' | head -1)"
[[ -n "$STORE_ID" ]] || die "WebStore '$STORE_NAME' not found. Run 10_create_store_and_site.sh first."
ok "WebStore Id: $STORE_ID"

API="/services/data/v67.0/commerce/management/webstores/$STORE_ID/search/indexes"

log "Current index state (read-only)"
sf_run api request rest "$API" --method GET --target-org "$TARGET_ORG" || true

log "Triggering a full index build"
sf_run api request rest "$API" --method POST --target-org "$TARGET_ORG" --body '{}' \
  || die "Index build request failed. EC-01 applies: record this as a boundary failure and build the index manually via Commerce App > Store > Search > Build Index."

log "Polling for completion (up to ~20 minutes)"
for attempt in $(seq 1 60); do
  state="$(sf_run api request rest "$API" --method GET --target-org "$TARGET_ORG" 2>/dev/null || true)"
  if grep -q '"indexStatus"[[:space:]]*:[[:space:]]*"Completed"' <<<"$state"; then
    ok "Search index build completed."
    printf '%s\n' "$state"
    break
  fi
  if grep -qiE '"indexStatus"[[:space:]]*:[[:space:]]*"(Failed|Error)"' <<<"$state"; then
    printf '%s\n' "$state"
    die "Index build FAILED. EC-01: document as a boundary failure and rebuild from the Commerce App."
  fi
  printf '.'
  sleep 20
  [[ $attempt -eq 60 ]] && warn "Still not Completed after ~20 minutes. Check Commerce App > Store > Search."
done

cat <<'NOTE'

MANUAL FALLBACK (EC-01 workaround, if the POST above is rejected):
  Setup -> Commerce App -> select the "Office Depot" store -> Search -> Build Search Index.
  Searchable / sortable field configuration (needed if you want Specification__c to surface on
  the product card) is Setup-UI only - there is no API for it.
NOTE

ok "Step 10 complete. Next: scripts/bash/60_publish_site.sh"
