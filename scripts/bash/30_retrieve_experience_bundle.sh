#!/usr/bin/env bash
# 30_retrieve_experience_bundle.sh - Canonical chain step 9a: bring the generated storefront
# pages under source control BEFORE configuring them.
# Traces to: FR-04 / US-04, BR-02.
#
# This is the single most important step for honouring BR-02 ("configure, never rebuild").
# The "Commerce Store (LWR)" template generates ~40 routes and ~45 views. Retrieving them
# first means every subsequent change is a diff against Salesforce's own standard pages
# rather than a hand-written replacement for them.
#
# Reference inventory retrieved from a sibling commerce store in this org on 2026-09-21
# (DigitalExperienceBundle:site/Retail_Supply_Store1) - these are the standard routes:
#   Home, Search, Category_Detail, Product_Detail, Current_Cart, Current_Checkout,
#   Order, Order_Summary, Order_Summary_List, Order_Lookup, Payment_Processing,
#   Login, Register, Forgot_Password, Check_Password, My_Profile, Address_List,
#   Address_Form, MyPaymentMethods_List, AddPaymentMethods, Wishlist, Quote,
#   Quote_Summary, Quote_Summary_List, Split_Shipment, Error, Service_Not_Available,
#   Too_Many_Requests, Privacy_Policy, Terms_And_Conditions
# and the standard theme layouts: commerceLayout, checkoutLayout, myAccountLayout,
# externalLayout, snaThemeLayout, with branding sets B2B_Commerce, B2B_Footer,
# B2B_Home_Banner, B2B_Right_Panel.
#
# This script only READS from the org. It writes into force-app/.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

log "Discovering the generated DigitalExperienceBundle name for '$STORE_NAME'"
sf_run org list metadata --target-org "$TARGET_ORG" --metadata-type DigitalExperienceBundle

cat <<'NOTE'

Find the row whose Full Name looks like  site/Office_Depot<N>  and export it, e.g.:
  export BUNDLE_NAME='site/Office_Depot'
Then re-run this script. Do NOT guess the suffix.
NOTE

BUNDLE_NAME="${BUNDLE_NAME:-}"
[[ -n "$BUNDLE_NAME" ]] || die "BUNDLE_NAME is not set. See the note above."

log "Retrieving $BUNDLE_NAME into force-app/"
sf_run project retrieve start --target-org "$TARGET_ORG" \
  --metadata "DigitalExperienceBundle:$BUNDLE_NAME" --wait 30

log "Retrieving the Network and CustomSite definitions for the same site"
sf_run project retrieve start --target-org "$TARGET_ORG" \
  --metadata "Network:$STORE_NAME" --wait 20 || warn "Network retrieve failed - check the exact Network name."

log "Standard routes now under source control"
find "$PROJECT_ROOT/force-app/main/default/digitalExperiences" -type d -name 'sfdc_cms__route' -exec ls -1 {} \; 2>/dev/null || true

ok "Step 9a complete. Review the diff, then run scripts/bash/40_deploy_storefront_config.sh"
