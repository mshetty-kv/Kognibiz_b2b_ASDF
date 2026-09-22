#!/usr/bin/env bash
# 60_publish_and_verify.sh - Canonical chain steps 11 and 12: publish/activate, then verify.
# Traces to: FR-04 / US-04, FR-05 / US-05, EC-01, SM-02.
#
# BOUNDARY STEP - CLASS 3. Publishing an Experience Builder site is not a metadata operation.
# `sf community publish` (plugin "community" v3.3.63, confirmed installed) is the supported
# automation. Site activation/status and the store's own activation toggles remain Setup UI.
#
# THIS SCRIPT MODIFIES THE ORG. Do not run it without explicit approval.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Step 11: publishing the Experience Builder site"
sf_run community publish --name "$STORE_NAME" --target-org "$TARGET_ORG" \
  || die "Publish failed. EC-01 applies: publish manually from Experience Builder and record the failure."

log "Confirming network status"
soql "SELECT Id, Name, Status, UrlPathPrefix FROM Network WHERE Name = '$STORE_NAME'"

cat <<'NOTE'

REMAINING MANUAL (SETUP UI) STEPS - none of these have an API or metadata path:
  1. (AUTOMATED) Site activation is NOT a Setup-UI step. Network.status is deployable metadata:
     set <status>Live</status> in force-app/main/default/networks/Office Depot.network-meta.xml
     and deploy it. Verified in scratch org 00DG100000EKcgz - Network went UnderConstruction -> Live.
     Note: the deploy fails with "unable to obtain exclusive access to this record" while the
     publish job is still running; wait for BackgroundOperation SiteTaskPublish to Complete.
  2. Commerce App -> Office Depot -> confirm the store is Active.
  3. Commerce App -> Office Depot -> Search -> Searchable and Sortable Fields
     (required if Specification__c is to appear on the product card).
  4. Payments: connect a payment gateway and complete gateway authentication.
     Per OQ-01 this is Class 3 and must be done before checkout can be validated.
  5. Experience Workspaces -> Administration -> Members: confirm the buyer profile is a member
     of the site, otherwise login returns "insufficient privileges".
  6. Set a password for the buyer user:
       sf org generate password --target-org officedepot-sc --on-behalf-of <buyer username>
NOTE

log "Step 12: full chain verification"
invoke_apex "OfficeDepotChainVerifier.execute();" || warn "Verification reported failures - see [FAIL] lines above."

log "End-to-end evidence for SM-02 (an order must exist for the PoC to count as passed)"
soql "SELECT Id, OrderNumber, Status, TotalAmount, AccountId FROM Order WHERE SalesStore.Name = '$STORE_NAME' ORDER BY CreatedDate DESC LIMIT 5"

cat <<'NOTE'

DEFINITION OF DONE REMINDER (Constitution, item 9):
Nothing in this project counts as done until a real buyer has logged in, browsed, added to
cart and placed an order, and that Order record is visible in the query above. Until that
query returns a row, the correct status is "authored and deployed", never "done".
NOTE
