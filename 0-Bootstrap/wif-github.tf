# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OPTIONAL: GitHub Actions Workload Identity Federation (WIF)               ║
# ║                                                                             ║
# ║  PURPOSE (Layman's Explanation):                                           ║
# ║    This allows GitHub Actions to deploy without storing credentials.       ║
# ║    Instead of API keys (risky!), GitHub proves its identity to GCP.       ║
# ║    GCP trusts GitHub, so GitHub can deploy infrastructure automatically.   ║
# ║                                                                             ║
# ║  WHEN TO USE:                                                              ║
# ║    Set enable_cicd_github: true in config.yaml                            ║
# ║                                                                             ║
# ║  COST IMPACT: $0 (just configuration, no resources)                        ║
# ║                                                                             ║
# ║  HOW IT WORKS:                                                             ║
# ║    1. GitHub Actions runs terraform deploy                               ║
# ║    2. GitHub proves its identity using JWT token                         ║
# ║    3. GCP verifies JWT (no API key needed!)                             ║
# ║    4. GCP issues temporary access token                                 ║
# ║    5. GitHub Actions uses token to deploy                              ║
# ║                                                                             ║
# ║  SECURITY: ✓✓✓ No long-lived credentials stored anywhere                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# This file is in 0-Bootstrap/ but only deployed if enable_cicd_github = true

################################################################################
# STEP 1: Create Workload Identity Pool (Trust Container for GitHub)
#
# Layman's explanation:
#   A "pool" is like a database of trusted parties.
#   We're saying: "GCP, trust any GitHub Actions run from our repo"
################################################################################

resource "google_iam_workload_identity_pool" "github" {
  count = try(local.config.enable_cicd_github, false) ? 1 : 0

  provider                  = google-beta
  project                   = local.org_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}

################################################################################
# STEP 2: Create OIDC Provider (Tell GCP where to verify GitHub tokens)
#
# Layman's explanation:
#   An OIDC provider is like a "stamp" that certifies GitHub's tokens are real.
#   GCP checks GitHub's digital signature on tokens before trusting them.
################################################################################

resource "google_iam_workload_identity_pool_provider" "github" {
  count = try(local.config.enable_cicd_github, false) ? 1 : 0

  provider                           = google-beta
  project                            = local.org_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  # Note: attribute_condition removed - GitHub Actions uses sts.googleapis.com as default audience
  # If you need to restrict by repository, use: "assertion.repository == 'YOUR_ORG/YOUR_REPO'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

################################################################################
# STEP 3: Create Service Account for GitHub (The Robot GitHub Uses)
#
# Layman's explanation:
#   GitHub needs its own service account to do things in GCP.
#   This account is the "robot" that GitHub impersonates.
################################################################################

resource "google_service_account" "github" {
  count = try(local.config.enable_cicd_github, false) ? 1 : 0

  project      = local.org_id
  account_id   = "github-ci-cd"
  display_name = "GitHub CI/CD Service Account"
  description  = "Service account for GitHub Actions CI/CD deployments"
}

################################################################################
# STEP 4: Grant Permissions (Let GitHub Service Account Do What It Needs)
#
# Layman's explanation:
#   Without permissions, the GitHub robot can't do anything.
#   We grant it permissions to deploy (edit) infrastructure.
################################################################################

resource "google_organization_iam_member" "github_terraform" {
  count = try(local.config.enable_cicd_github, false) ? 1 : 0

  org_id = local.org_id
  role   = "roles/editor" # Broad permissions (should narrow in production)
  member = "serviceAccount:${google_service_account.github[0].email}"

  # Better for production: use custom roles with minimal permissions
  # For now, "editor" allows Terraform to deploy
}

################################################################################
# STEP 5: Link GitHub to Service Account (Trust Relationship)
#
# Layman's explanation:
#   Now we tie it together: "GitHub, when you authenticate with your JWT,
#   I'll let you impersonate the GitHub service account"
################################################################################

resource "google_service_account_iam_member" "github_impersonate" {
  count = try(local.config.enable_cicd_github, false) ? 1 : 0

  service_account_id = google_service_account.github[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${local.org_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github[0].workload_identity_pool_id}/attribute.repository/${local.config.cicd.github_repository}"
}

################################################################################
# OUTPUT: GitHub Actions Integration Instructions
################################################################################

# See outputs.tf for WIF configuration details
