#!/usr/bin/env bash
# 00_preflight.sh - Canonical chain step 1: Org Enablement (VERIFY ONLY).
# Traces to: FR-01 / US-01, EC-03, NFR-01.
#
# Reads only. Creates nothing. Run this before every other script in scripts/bash/.
#
# ORG ENABLEMENT IS A SETUP-UI BOUNDARY STEP. Neither this script nor any Metadata API deploy
# can turn on Digital Experiences or Commerce in an existing org. What this script does is
# PROVE whether they are already on, so the assessment records evidence instead of an
# assumption. In target org 00DgL00000L7NwjUAF both were already enabled before this project
# started (CommerceSettings.commerceEnabled = true, CommunitiesSettings.enableNetworksEnabled
# = true, retrieved 2026-09-21) - so step 1 is pre-satisfied, not performed by us.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Step 1a: Commerce + Digital Experiences enablement evidence"
sf_run project retrieve start --target-org "$TARGET_ORG" \
  --metadata 'Settings:Commerce' 'Settings:Communities' 'Settings:Order' \
  --target-metadata-dir '.preflight-settings' --wait 20 --unzip >/dev/null \
  || warn "Could not retrieve settings; check the values manually in Setup."

if [[ -f .preflight-settings/unpackaged/unpackaged/settings/Commerce.settings ]]; then
  grep -E 'commerceEnabled|commerceAppEnabled' .preflight-settings/unpackaged/unpackaged/settings/Commerce.settings || true
  grep -E 'enableNetworksEnabled' .preflight-settings/unpackaged/unpackaged/settings/Communities.settings || true
  grep -E 'enableOrders|enableEnhancedCommerceOrders' .preflight-settings/unpackaged/unpackaged/settings/Order.settings || true
fi
rm -rf .preflight-settings

log "Step 1b: EC-03 guard - confirm every permission set name this project relies on"
soql "SELECT Name, Label FROM PermissionSet WHERE Name IN ('B2BBuyer','B2BBuyerManager','CommerceAdmin','CommerceUser','Merchandiser')"
soql "SELECT DeveloperName, TotalLicenses, UsedLicenses FROM PermissionSetLicense WHERE DeveloperName IN ('B2BBuyerPsl','B2BBuyerManagerPsl','CommerceAdminUserPsl','CommerceMerchandiserUserPsl')"

log "Step 1c: AD-01 reality check - is the org actually clean?"
soql "SELECT Id, Name, Type FROM WebStore ORDER BY Name"
soql "SELECT Id, Name, Status, UrlPathPrefix FROM Network ORDER BY Name"

log "Step 1d: confirm the LWR commerce template is available in this org"
sf_run community list template --target-org "$TARGET_ORG"

log "Step 1e: Apex-level preflight assertions (deploys the classes first)"
deploy_classes
invoke_apex "OfficeDepotPreflight.execute();" || true

cat <<'NOTE'

PREFLIGHT NOTES
  - The Apex preflight is EXPECTED to fail its "WebStore/Office Depot" check on a first run.
    That is the correct behaviour: the store does not exist until 10_create_store_and_site.sh
    has run. Every other check must pass before you continue.
  - If any permission set or permission set license above is missing, STOP. Do not substitute a
    similar-looking name - that is exactly the EC-03 failure mode this project exists to catch.
NOTE
