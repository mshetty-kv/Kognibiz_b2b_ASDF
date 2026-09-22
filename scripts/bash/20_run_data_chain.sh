#!/usr/bin/env bash
# 20_run_data_chain.sh - Canonical chain steps 3 to 8, in strict BR-01 order.
# Traces to: FR-02 / US-02, FR-03 / US-03, NFR-01.
#
#   step 3  Settings / Integrations         OfficeDepotStoreSettings
#   step 4  Catalog / Categories / Products OfficeDepotCatalogSeeder
#   step 5  Pricebooks / Entries            OfficeDepotPricebookSeeder
#   step 3' Settings re-run                 OfficeDepotStoreSettings          (see note)
#   step 3d Shipping Profile                OfficeDepotShippingConfigurator
#   step 6  Entitlements / Buyer Groups     OfficeDepotEntitlementSeeder
#   step 7a Accounts / Contacts             OfficeDepotBuyerIdentitySeeder
#   step 7b Buyer Users                     OfficeDepotBuyerUserProvisioner
#   step 8  Memberships / Links             OfficeDepotStoreLinker
#   step 8b Permission assignment           OfficeDepotPermissionAssigner
#
# All logic lives in deployable classes under force-app/main/default/classes/. This script is
# orchestration only: it deploys those classes, then calls their static entry points in order.
#
# NEVER reorder these. invoke_apex halts the whole chain on the first failure so a dependency
# violation can never cascade into later steps (NFR-01 target: 0 out-of-order errors).
#
# THIS SCRIPT CREATES ORG RECORDS. Do not run it without explicit approval.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

require_org

# The classes carry no dependency on the store, so they can be deployed as soon as the org is
# reachable. They must exist before any invoke_apex call below.
deploy_classes
deploy_settings

invoke_apex "OfficeDepotPreflight.execute();"

invoke_apex "OfficeDepotStoreSettings.execute();"
invoke_apex "OfficeDepotCatalogSeeder.execute();"
invoke_apex "OfficeDepotPricebookSeeder.execute();"

# Deliberate second pass. WebStore.StrikethroughPricebookId can only be set once the list
# pricebook exists, and the pricebook cannot exist before the products it prices. Re-running
# step 3 after step 5 resolves that ordering constraint without violating it. The script is
# idempotent, so this is safe.
log "Re-running step 3 to wire StrikethroughPricebookId now that the list pricebook exists"
invoke_apex "OfficeDepotStoreSettings.execute();"

# Step 3d - Shipping Profile. Runs after products and pricebooks exist.
# Without the ShippingConfigurationSet chain, checkout dies with COMPUTE_SHIPPING and no
# delivery method can ever be selected. OrderDeliveryMethod alone is NOT enough.
invoke_apex "OfficeDepotShippingConfigurator.execute();"

invoke_apex "OfficeDepotEntitlementSeeder.execute();"
invoke_apex "OfficeDepotBuyerIdentitySeeder.execute();"

# Portal user creation requires the buyer Account OWNER to hold a UserRole. A fresh scratch org
# has no role hierarchy, so ensure one exists before provisioning users.
ensure_owner_role

# 55 must be a SEPARATE transaction from 50: User is a setup sObject and would otherwise
# raise MIXED_DML_OPERATION. This is the structural answer to EC-02.
invoke_apex "OfficeDepotBuyerUserProvisioner.execute();"

invoke_apex "OfficeDepotStoreLinker.execute();"

# Phase 2 MUST be a separate transaction: the platform does not recognise a BuyerAccount that
# was inserted earlier in the same transaction, and the resulting exception rolls back every
# link created in phase 1. Verified in scratch org 00DG100000EKcgz on 2026-09-21.
invoke_apex "OfficeDepotStoreLinker.executeBuyerGroupMembership();"
invoke_apex "OfficeDepotPermissionAssigner.execute();"

log "Chain data verification"
invoke_apex "OfficeDepotChainVerifier.execute();"

ok "Steps 3-8 complete. Next: scripts/bash/30_retrieve_experience_bundle.sh"
