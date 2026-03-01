# Purpose: Reads config.yaml and publishes shared resource-manager locals.
# Why a layman needs this: Keeps project onboarding behavior predictable.
# Cost Impact: $0 (local calculations only).
locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  org_id          = local.config.organization_id
  billing_account = local.config.billing_account
  default_region  = local.config.default_region

  spokes = try(local.config.spokes, [])

  labels = {
    managed-by = "terraform"
    finops     = "enabled"
    framework  = "gcp-architecture-framework-2026"
  }
}
