# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 0: BOOTSTRAP                                                        ║
# ║  Purpose: Prepares org-level services, IAM, folder, and Terraform state.  ║
# ║  Why a layman needs this: Later phases fail without these prerequisites.   ║
# ║  Cost Impact: Very low (mostly API enablement and small state storage).    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = local.org_id
  region  = local.default_region
}

locals {
  optional_apis = concat(
    local.has_gcve_foundation ? try(local.config.service_catalog.gcve_apis, []) : [],
    local.has_gke_multicloud_foundation ? try(local.config.service_catalog.gke_multicloud_apis, []) : [],
    local.has_migration_foundation ? try(local.config.service_catalog.migration_apis, []) : []
  )

  required_apis = distinct(concat(try(local.config.service_catalog.base_apis, []), local.optional_apis))
}

resource "terraform_data" "validate_config_schema" {
  lifecycle {
    precondition {
      condition     = trimspace(try(local.config.organization_id, "")) != "" && local.config.organization_id != "YOUR_ORG_ID"
      error_message = "config.yaml: organization_id must be set to a real value."
    }

    precondition {
      condition     = trimspace(try(local.config.billing_account, "")) != "" && local.config.billing_account != "YOUR_BILLING_ID"
      error_message = "config.yaml: billing_account must be set to a real value."
    }

    precondition {
      condition     = trimspace(try(local.config.default_region, "")) != ""
      error_message = "config.yaml: default_region is required."
    }

    precondition {
      condition     = can(local.config.global_modules.enable_scc_standard) && can(local.config.global_modules.enable_iap_access) && can(local.config.global_modules.enable_cloud_nat) && can(local.config.global_modules.enable_hybrid_connectivity) && can(local.config.global_modules.enable_central_logging) && can(local.config.global_modules.enable_private_service_connect) && can(local.config.global_modules.enable_secret_manager)
      error_message = "config.yaml: global_modules must include enable_scc_standard, enable_iap_access, enable_cloud_nat, enable_hybrid_connectivity, enable_central_logging, enable_private_service_connect, and enable_secret_manager."
    }

    precondition {
      condition     = can(local.config.advanced_modules.enable_centralized_ingress) && can(local.config.advanced_modules.enable_egress_inspection)
      error_message = "config.yaml: advanced_modules must include enable_centralized_ingress and enable_egress_inspection."
    }

    precondition {
      condition     = can(local.config.hub.name) && can(local.config.hub.network_cidr) && can(local.config.hub.iap_source_ranges)
      error_message = "config.yaml: hub must include name, network_cidr, and iap_source_ranges."
    }

    precondition {
      condition     = can(local.config.service_catalog.base_apis) && can(local.config.service_catalog.gcve_apis) && can(local.config.service_catalog.gke_multicloud_apis) && can(local.config.service_catalog.migration_apis) && can(local.config.service_catalog.service_networking_api) && can(local.config.service_catalog.security_center_api)
      error_message = "config.yaml: service_catalog must define base_apis, gcve_apis, gke_multicloud_apis, migration_apis, service_networking_api, and security_center_api."
    }

    precondition {
      condition     = !try(local.config.enable_cicd_github, false) || try(length(trimspace(local.config.cicd.github_repository)) > 0, false)
      error_message = "config.yaml: cicd.github_repository must be set when enable_cicd_github is true."
    }

    precondition {
      condition     = length(try(local.config.spokes, [])) > 0
      error_message = "config.yaml: spokes must contain at least one spoke."
    }

    precondition {
      condition     = alltrue([for s in local.spokes : contains(["greenfield", "brownfield_adopt", "brownfield_reference"], try(s.type, ""))])
      error_message = "config.yaml: spoke.type must be greenfield, brownfield_adopt, or brownfield_reference."
    }

    precondition {
      condition     = alltrue([for s in local.spokes : contains(["strict_free", "custom_mix"], try(s.cost_mode, "custom_mix"))])
      error_message = "config.yaml: spoke.cost_mode must be strict_free or custom_mix."
    }
  }
}

resource "google_project_service" "required_apis" {
  for_each = toset(local.required_apis)

  project            = local.org_id
  service            = each.value
  disable_on_destroy = false

  timeouts {
    create = "30m"
    update = "30m"
  }

  depends_on = [terraform_data.validate_config_schema]
}

resource "google_service_account" "terraform" {
  display_name = "Terraform Landing Zone Service Account"
  account_id   = "terraform-lz"
  description  = "Service account used for landing zone deployments"

  depends_on = [google_project_service.required_apis]
}

resource "google_organization_iam_member" "terraform_org_admin" {
  org_id = local.org_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_organization_iam_member" "terraform_folder_admin" {
  org_id = local.org_id
  role   = "roles/resourcemanager.folderAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_billing_account_iam_member" "terraform_billing" {
  billing_account_id = local.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_folder" "landing_zone" {
  display_name = "Landing Zone Projects"
  parent       = "organizations/${local.org_id}"

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "terraform_state" {
  name          = "${local.org_id}-terraform-state"
  location      = local.default_region
  project       = local.org_id
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  labels = merge(local.labels, {
    purpose = "terraform-state"
  })

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket_object" "terraform_lock" {
  bucket  = google_storage_bucket.terraform_state.name
  name    = ".terraform.lock.hcl"
  content = "# Terraform state locking marker\n"
}
