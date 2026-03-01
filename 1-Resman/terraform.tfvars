# terraform.tfvars - Phase 1: Resource Manager
# Optional configuration for Phase 1

# GCS bucket where Terraform state is stored (from bootstrap.sh output)
# This is passed from the backend-config.hcl, but can be overridden here if needed
# terraform_state_bucket = "lz-automation-12345-tf-state"

# Whether GCP automatically creates default networks (usually false for security)
auto_create_network = false

# Add liens to projects to prevent accidental deletion via gcloud/console
enable_project_deletion_restrictions = true
