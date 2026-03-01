# Purpose: Exposes managed and referenced project/network metadata.
# Why a layman needs this: Next phase consumes these values automatically.
# Cost Impact: $0 (outputs only).

output "spoke_projects" {
  description = "Managed spoke projects from greenfield and brownfield_adopt"
  value = {
    for name, project in merge(
      { for n, p in google_project.spoke_greenfield : n => p },
      { for n, p in google_project.spoke_brownfield_adopt : n => p }
      ) : name => {
      project_id   = project.project_id
      project_name = project.name
      folder_id    = project.folder_id
    }
  }
}

output "brownfield_reference_network_ids" {
  description = "Reference-only legacy network IDs from config"
  value = {
    for name, spoke in local.brownfield_reference_spokes :
    name => spoke.existing_network_id
  }
}

output "auto_corrected_features" {
  description = "List of module settings changed by strict_free auto-corrector in this phase"
  value       = []
}

output "default_injected_values" {
  description = "Default values injected when optional YAML keys were absent"
  value = [
    "spoke.cost_mode defaulted to custom_mix when omitted",
    "spoke.workload_foundations defaults to all false when omitted"
  ]
}

output "resman_complete" {
  description = "Status summary"
  value       = "Resource Manager phase complete. Managed projects and brownfield references are ready."
}
