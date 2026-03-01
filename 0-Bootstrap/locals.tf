# Purpose: Reads config.yaml and publishes shared bootstrap locals.
# Why a layman needs this: Keeps all bootstrap resources aligned to one config.
# Cost Impact: $0 (local calculations only).
locals {
  config = yamldecode(file("${path.module}/../config.yaml"))

  org_id          = local.config.organization_id
  billing_account = local.config.billing_account
  default_region  = local.config.default_region

  global_modules = try(local.config.global_modules, {})
  spokes         = try(local.config.spokes, [])

  has_gcve_foundation = anytrue([
    for spoke in local.spokes :
    try(spoke.workload_foundations.enable_gcve_networking, false)
  ])

  has_gke_multicloud_foundation = anytrue([
    for spoke in local.spokes :
    try(spoke.workload_foundations.enable_gke_multi_cloud, false)
  ])

  has_migration_foundation = anytrue([
    for spoke in local.spokes :
    try(spoke.workload_foundations.enable_migration_factory, false)
  ])

  labels = {
    managed-by = "terraform"
    finops     = "enabled"
    framework  = "gcp-architecture-framework-2026"
  }
}
