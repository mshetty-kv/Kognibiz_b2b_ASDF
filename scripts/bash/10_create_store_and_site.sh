#!/usr/bin/env bash
# 10_create_store_and_site.sh - Canonical chain step 2: WebStore + linked Experience Cloud LWR site.
# Traces to: FR-01 / US-01.
#
# BOUNDARY STEP - CLASS 3 (requires Salesforce config outside a metadata deploy).
# There is no WebStore metadata type. Verified against org 00DgL00000L7NwjUAF on 2026-09-21:
#   sf org list metadata-types  ->  WebStoreTemplate exists, WebStore does NOT.
#   sf org list metadata --metadata-type WebStoreTemplate  ->  zero records.
# A B2B store therefore cannot be produced by `sf project deploy start`. The supported
# automation is `sf community create` against the "Commerce Store (LWR)" template, which
# provisions the whole cluster in one asynchronous job:
#   Network + CustomSite + SiteDotCom + DigitalExperienceBundle + DigitalExperienceConfig
#   + WebStore + WebStoreNetwork + "<Name> Profile" (guest) + "<Name> Shopper Profile"
# This pattern was confirmed by inspecting the five stores that already exist in this org.
#
# THIS SCRIPT CREATES ORG RECORDS. Do not run it without explicit approval.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Guard: refuse to clobber an existing store named '$STORE_NAME'"
existing="$(soql "SELECT Id, Name FROM WebStore WHERE Name = '$STORE_NAME'" || true)"
if grep -q "$STORE_NAME" <<<"$existing"; then
  ok "WebStore '$STORE_NAME' already exists - skipping creation (idempotent)."
  printf '%s\n' "$existing"
  exit 0
fi

log "Confirming the template exists before using its name"
sf_run community list template --target-org "$TARGET_ORG" | grep -F "$SITE_TEMPLATE" \
  || die "Template '$SITE_TEMPLATE' not available in this org. Do not substitute another template name."

log "Creating site + store: '$STORE_NAME' at /$URL_PATH_PREFIX"
sf_run community create \
  --name "$STORE_NAME" \
  --template-name "$SITE_TEMPLATE" \
  --url-path-prefix "$URL_PATH_PREFIX" \
  --target-org "$TARGET_ORG" \
  --description "Office Depot B2B Commerce (LWR) storefront - ASDF capability validation."

cat <<'NOTE'

Site creation is ASYNCHRONOUS. sf returns a jobId; the records appear minutes later.
Poll with:
  sf data query -o officedepot-sc -q "SELECT Id, Status, Type FROM BackgroundOperation ORDER BY CreatedDate DESC LIMIT 5"
NOTE

log "Polling for the WebStore and its network link (up to ~10 minutes)"
for attempt in $(seq 1 60); do
  result="$(soql "SELECT Id, Name FROM WebStore WHERE Name = '$STORE_NAME'" 2>/dev/null || true)"
  if grep -q "$STORE_NAME" <<<"$result"; then
    ok "WebStore created."
    printf '%s\n' "$result"
    break
  fi
  printf '.'
  sleep 10
  [[ $attempt -eq 60 ]] && die "Timed out waiting for WebStore '$STORE_NAME'. Check BackgroundOperation."
done

log "Verifying the WebStore <-> Network link and the generated profiles"
soql "SELECT Id, WebStore.Name, Network.Name, Network.Status FROM WebStoreNetwork WHERE WebStore.Name = '$STORE_NAME'"
soql "SELECT Id, Name, UserLicense.Name, UserType FROM Profile WHERE Name LIKE '$STORE_NAME%'"

log "Recording the generated DigitalExperienceBundle name"
sf_run org list metadata --target-org "$TARGET_ORG" --metadata-type DigitalExperienceBundle | grep -i "office" || true

cat <<'NOTE'

IMPORTANT - VERIFY THE BUNDLE NAME BEFORE DEPLOYING BRANDING.
Experience Cloud appends a numeric suffix to the site's metadata name (observed in this org:
network "Retail Supply Store" -> bundle "site/Retail_Supply_Store1"). This repo pre-authors
branding at:
  force-app/main/default/digitalExperiences/site/Office_Depot/...
If the command above reports a different bundle name, RENAME that folder to match before
running 40_deploy_storefront_config.sh. Do not deploy a guessed path.
NOTE

ok "Step 2 complete. Next: scripts/bash/20_run_data_chain.sh"
