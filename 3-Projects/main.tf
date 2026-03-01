# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 3: PROJECTS                                                         ║
# ║  Purpose: Applies governance, budgets, and security controls per project.  ║
# ║  Why a layman needs this: Prevents surprise bills and enforces guardrails. ║
# ║  Cost Impact: Budget checks are free; optional logging controls may cost.  ║
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

data "terraform_remote_state" "resman" {
  backend = "gcs"
  config = {
    bucket = "${local.org_id}-terraform-state"
    prefix = "terraform/state/1-Resman"
  }
}

# NOTE: Networking remote state declared for future use (e.g., firewall rules, IAM bindings)
# Currently not consumed but available for extending governance phase with network-aware policies
data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "${local.org_id}-terraform-state"
    prefix = "terraform/state/2-Networking"
  }
}

locals {
  managed_spokes = {
    for spoke in local.spokes :
    spoke.name => spoke
    if spoke.type != "brownfield_reference"
  }

  spoke_cost_mode = {
    for name, spoke in local.managed_spokes :
    name => try(spoke.cost_mode, "custom_mix")
  }

  budget_threshold = try(tonumber(local.config.budget_alert_threshold), 1)
  budget_units     = floor(local.budget_threshold)
  budget_nanos     = floor((local.budget_threshold - local.budget_units) * 1000000000)

  # This phase has no additional chargeable toggles in the new template,
  # but we still emit transparency outputs for consistency.
  auto_corrected_features = []

  default_injected_values = compact([
    can(local.config.budget_alert_threshold) ? "" : "budget_alert_threshold defaulted to 1 USD"
  ])
}

resource "terraform_data" "validate_projects_inputs" {
  lifecycle {
    precondition {
      condition     = local.budget_threshold > 0
      error_message = "budget_alert_threshold must be a positive number."
    }
  }
}

resource "google_billing_budget" "spoke_budgets" {
  for_each = local.managed_spokes

  billing_account = local.billing_account
  display_name    = "Budget Alert: ${each.key} spoke"

  budget_filter {
    projects = ["projects/${data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(local.budget_units)
      nanos         = local.budget_nanos
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 1
  }

  depends_on = [terraform_data.validate_projects_inputs]
}

resource "google_monitoring_notification_channel" "email" {
  count = length(var.alert_email) > 0 ? 1 : 0

  display_name = "Landing zone alerts"
  type         = "email"
  project      = local.org_id

  labels = {
    email_address = var.alert_email
  }
}

# SCC standard is controlled as an API/module enablement gate.
resource "google_project_service" "scc_standard" {
  for_each = try(local.global_modules.enable_scc_standard, true) ? local.managed_spokes : tomap({})

  project            = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  service            = local.config.service_catalog.security_center_api
  disable_on_destroy = false
}
