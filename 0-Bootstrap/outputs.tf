# Purpose: Exposes bootstrap IDs for the next phases.
# Why a layman needs this: Later phases read these values automatically.
# Cost Impact: $0 (outputs only).

output "terraform_service_account_email" {
  description = "Email of the Terraform service account (used for impersonation)"
  value       = google_service_account.terraform.email
}

output "terraform_service_account_id" {
  description = "Unique ID of the Terraform service account"
  value       = google_service_account.terraform.unique_id
}

output "landing_zone_folder_id" {
  description = "Folder ID where all landing zone projects will be created"
  value       = google_folder.landing_zone.folder_id
}

output "landing_zone_folder_name" {
  description = "Folder name for reference"
  value       = google_folder.landing_zone.display_name
}

output "terraform_state_bucket" {
  description = "GCS bucket name where Terraform state is stored"
  value       = google_storage_bucket.terraform_state.name
}

output "terraform_state_bucket_url" {
  description = "Full URL to the Terraform state bucket"
  value       = "gs://${google_storage_bucket.terraform_state.name}"
}

output "bootstrap_complete" {
  description = "Status message"
  value       = "✓ Bootstrap phase complete. Terraform service account and folder created."
}

output "bootstrap_default_injected_values" {
  description = "Safe defaults injected when config keys were missing"
  value = compact([
    can(local.config.global_modules.enable_scc_standard) ? "" : "global_modules.enable_scc_standard defaulted by downstream modules",
    can(local.config.global_modules.enable_iap_access) ? "" : "global_modules.enable_iap_access defaulted by downstream modules",
    can(local.config.global_modules.enable_cloud_nat) ? "" : "global_modules.enable_cloud_nat defaulted by downstream modules",
    can(local.config.global_modules.enable_hybrid_connectivity) ? "" : "global_modules.enable_hybrid_connectivity defaulted by downstream modules"
  ])
}

################################################################################
# GitHub Actions WIF Outputs (if enabled)
################################################################################

output "github_wif_pool_id" {
  description = "Workload Identity Pool ID for GitHub (use in .github/workflows)"
  value       = try(google_iam_workload_identity_pool.github[0].workload_identity_pool_id, "Not enabled")
}

output "github_wif_provider_id" {
  description = "Workload Identity Provider ID for GitHub"
  value       = try(google_iam_workload_identity_pool_provider.github[0].workload_identity_pool_provider_id, "Not enabled")
}

output "github_service_account_email" {
  description = "Service account email for GitHub Actions (use in .github/workflows)"
  value       = try(google_service_account.github[0].email, "Not enabled")
}

output "github_wif_setup_instructions" {
  description = "Instructions for configuring GitHub Actions with WIF"
  value = try(local.config.enable_cicd_github, false) ? trimspace(<<EOT
GitHub Actions WIF Configuration:

1. In your GitHub repository, create .github/workflows/terraform.yml

2. Add this to your workflow:

permissions:
  contents: 'read'
  id-token: 'write'

steps:
  - uses: actions/checkout@v3

  - uses: google-github-actions/auth@v1
    with:
      workload_identity_provider: projects/${local.org_id}/locations/global/workloadIdentityPools/github-pool/providers/github-provider
      service_account: ${try(google_service_account.github[0].email, "SERVICE_ACCOUNT_EMAIL")}

  - uses: google-github-actions/setup-gcloud@v1

  - name: Terraform Deploy
    run: |
      cd 0-Bootstrap
      terraform init -backend-config=backend-config.hcl
      terraform apply -auto-approve

3. In Terraform code (wif-github.tf), update the principal set with your repo:
   principalSet://iam.googleapis.com/projects/...attribute.repository/YOUR_ORG/YOUR_REPO
EOT
  ) : "WIF not enabled (set enable_cicd_github: true in config.yaml)"
}
