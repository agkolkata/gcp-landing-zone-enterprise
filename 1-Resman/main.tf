# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 1: RESOURCE MANAGER                                                 ║
# ║  Purpose: Creates new projects, adopts existing projects, and tracks       ║
# ║  brownfield references for downstream networking.                           ║
# ║  Why a layman needs this: Projects are the security and billing boundary.  ║
# ║  Cost Impact: $0 for project objects (resource usage cost starts later).   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  region  = local.default_region
  project = local.org_id
}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = "${local.org_id}-terraform-state"
    prefix = "terraform/state/0-Bootstrap"
  }
}

locals {
  bootstrap_output = data.terraform_remote_state.bootstrap.outputs

  greenfield_spokes = {
    for spoke in local.spokes :
    spoke.name => spoke
    if spoke.type == "greenfield"
  }

  brownfield_adopt_spokes = {
    for spoke in local.spokes :
    spoke.name => spoke
    if spoke.type == "brownfield_adopt"
  }

  brownfield_reference_spokes = {
    for spoke in local.spokes :
    spoke.name => spoke
    if spoke.type == "brownfield_reference"
  }
}

resource "terraform_data" "validate_spokes" {
  for_each = { for spoke in local.spokes : spoke.name => spoke }

  lifecycle {
    precondition {
      condition     = contains(["greenfield", "brownfield_adopt", "brownfield_reference"], each.value.type)
      error_message = "Spoke '${each.key}' has invalid type. Use greenfield, brownfield_adopt, or brownfield_reference."
    }

    precondition {
      condition     = contains(["strict_free", "custom_mix"], try(each.value.cost_mode, "custom_mix"))
      error_message = "Spoke '${each.key}' has invalid cost_mode. Use strict_free or custom_mix."
    }

    precondition {
      condition     = each.value.type != "brownfield_adopt" || try(length(trimspace(each.value.existing_project_id)) > 0, false)
      error_message = "brownfield_adopt spoke '${each.key}' must include existing_project_id."
    }

    precondition {
      condition     = each.value.type != "brownfield_reference" || try(length(trimspace(each.value.existing_network_id)) > 0, false)
      error_message = "brownfield_reference spoke '${each.key}' must include existing_network_id."
    }

    precondition {
      condition = each.value.type != "brownfield_reference" || can(regex(
        "^projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/global/networks/[a-z]([-a-z0-9]{0,61}[a-z0-9])?$",
        each.value.existing_network_id
      ))
      error_message = "brownfield_reference spoke '${each.key}' existing_network_id must match projects/<project-id>/global/networks/<network-name>."
    }
  }
}

resource "google_project" "spoke_greenfield" {
  for_each = local.greenfield_spokes

  name                = "${each.key}-project"
  project_id          = "${substr(replace(each.key, "_", "-"), 0, 20)}-${substr(md5(each.key), 0, 6)}"
  folder_id           = local.bootstrap_output.landing_zone_folder_id
  billing_account     = local.billing_account
  org_id              = local.org_id
  auto_create_network = var.auto_create_network

  labels = merge(local.labels, try(each.value.labels, {}), {
    spoke     = each.key
    cost-mode = try(each.value.cost_mode, "custom_mix")
  })

  depends_on = [terraform_data.validate_spokes]
}

resource "google_project" "spoke_brownfield_adopt" {
  for_each = local.brownfield_adopt_spokes

  name            = each.key
  project_id      = each.value.existing_project_id
  folder_id       = local.bootstrap_output.landing_zone_folder_id
  billing_account = local.billing_account

  labels = merge(local.labels, try(each.value.labels, {}), {
    spoke     = each.key
    cost-mode = try(each.value.cost_mode, "custom_mix")
  })

  lifecycle {
    ignore_changes = [name, org_id]
  }

  depends_on = [terraform_data.validate_spokes]
}

# Adopt existing project state with native Terraform import blocks.
import {
  for_each = local.brownfield_adopt_spokes
  to       = google_project.spoke_brownfield_adopt[each.key]
  id       = each.value.existing_project_id
}

resource "google_billing_project_info" "spoke_billing" {
  for_each = merge(
    { for name, project in google_project.spoke_greenfield : name => project },
    { for name, project in google_project.spoke_brownfield_adopt : name => project }
  )

  project         = each.value.project_id
  billing_account = local.billing_account
}

locals {
  managed_projects = merge(
    { for name, project in google_project.spoke_greenfield : name => project.project_id },
    { for name, project in google_project.spoke_brownfield_adopt : name => project.project_id }
  )

  needs_gke_multicloud_api = {
    for name, spoke in merge(local.greenfield_spokes, local.brownfield_adopt_spokes) :
    name => try(spoke.workload_foundations.enable_gke_multi_cloud, false)
  }

  needs_migration_api = {
    for name, spoke in merge(local.greenfield_spokes, local.brownfield_adopt_spokes) :
    name => try(spoke.workload_foundations.enable_migration_factory, false)
  }
}

resource "google_project_service" "spoke_apis" {
  for_each = {
    for pair in flatten([
      for spoke_name, project_id in local.managed_projects : [
        for api in distinct(concat([
          "compute.googleapis.com",
          "storage.googleapis.com",
          "logging.googleapis.com",
          "monitoring.googleapis.com",
          "iam.googleapis.com",
          "cloudkms.googleapis.com",
          local.config.service_catalog.service_networking_api
        ],
        local.needs_gke_multicloud_api[spoke_name] ? ["gkehub.googleapis.com", "container.googleapis.com"] : [],
        local.needs_migration_api[spoke_name] ? ["vmmigration.googleapis.com", "storagetransfer.googleapis.com"] : []
        )) : {
          key        = "${spoke_name}/${api}"
          project_id = project_id
          api        = api
        }
      ]
    ]) : pair.key => pair
  }

  project            = each.value.project_id
  service            = each.value.api
  disable_on_destroy = false

  depends_on = [google_billing_project_info.spoke_billing]
}

resource "google_service_account" "spoke_default" {
  for_each = local.managed_projects

  project      = each.value
  account_id   = "default-${substr(each.value, 0, 15)}"
  display_name = "Default service account for ${each.key}"
  description  = "Default application service account"

  depends_on = [google_project_service.spoke_apis]
}

resource "google_project_iam_member" "terraform_spoke_editor" {
  for_each = local.managed_projects

  project = each.value
  role    = "roles/editor"
  member  = "serviceAccount:${local.bootstrap_output.terraform_service_account_email}"

  depends_on = [google_project_service.spoke_apis]
}

resource "google_resource_manager_lien" "project_deletion_restriction" {
  for_each = var.enable_project_deletion_restrictions ? local.managed_projects : {}

  parent       = "projects/${each.value}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "terraform-gcp-landing-zone"
  reason       = "Terraform-managed landing zone project"

  depends_on = [google_project_service.spoke_apis]
}
