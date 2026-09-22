#!/usr/bin/env bash
# 40_deploy_storefront_config.sh - Canonical chain step 9b: deploy permission sets and the
# storefront branding overlay.
# Traces to: FR-03 / US-03, FR-04 / US-04, BR-02.
#
# Deploys ONLY:
#   force-app/main/default/permissionsets/          (2 supplemental sets, real API names)
#   force-app/main/default/digitalExperiences/...   (branding set overlay, 269 verified keys)
#
# It deliberately does NOT deploy replacement routes or views. The Amazon-reference layouts in
# the brief are reproduced by CONFIGURING standard components already present on the generated
# pages - see docs/ASDF_ASSESSMENT.md section "Visual reference mapping" for the component-by-
# component mapping and for the three cases where no standard component exists.
#
# THIS SCRIPT MODIFIES THE ORG. Do not run it without explicit approval.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Step 9b-1: VALIDATION ONLY (check-only deploy, no changes committed)"
sf_run project deploy start --target-org "$TARGET_ORG" \
  --source-dir "$PROJECT_ROOT/force-app/main/default/permissionsets" \
  --dry-run --wait 20 \
  || die "Permission set validation failed. Fix before deploying - do not force."

ok "Permission sets validate cleanly."

read -r -p "Proceed with the real permission set deploy? [y/N] " reply
[[ "$reply" == "y" || "$reply" == "Y" ]] || die "Aborted by operator."

log "Step 9b-2: deploying permission sets"
sf_run project deploy start --target-org "$TARGET_ORG" \
  --source-dir "$PROJECT_ROOT/force-app/main/default/permissionsets" --wait 20

BUNDLE_DIR="$PROJECT_ROOT/force-app/main/default/digitalExperiences"
if [[ -d "$BUNDLE_DIR" ]]; then
  log "Step 9b-3: validating the branding overlay"
  sf_run project deploy start --target-org "$TARGET_ORG" \
    --source-dir "$BUNDLE_DIR" --dry-run --wait 30 \
    || die "Branding validation failed. The most likely cause is a bundle folder name that does not match the site's actual metadata name - verify it and rename the folder."

  read -r -p "Proceed with the real branding deploy? [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]] || die "Aborted by operator."

  log "Step 9b-4: deploying the branding overlay"
  sf_run project deploy start --target-org "$TARGET_ORG" --source-dir "$BUNDLE_DIR" --wait 30
else
  warn "No digitalExperiences directory found - skipping branding deploy."
fi

log "Assigning the supplemental admin permission set to the running user"
sf_run org assign permset --target-org "$TARGET_ORG" --name Office_Depot_Commerce_Admin \
  || warn "Assignment failed - assign manually in Setup."

ok "Step 9b complete. Next: scripts/bash/50_build_search_index.sh"
