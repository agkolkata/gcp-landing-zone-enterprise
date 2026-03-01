# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 2 OUTPUTS                                                           ║
# ║  Purpose: Shows created and referenced network details plus IPAM results.  ║
# ║  Why a layman needs this: Confirms no overlap and shows automatic decisions.║
# ║  Cost Impact: $0 (outputs only).                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

output "hub_network" {
  description = "Hub VPC details"
  value = {
    name = google_compute_network.hub.name
    id   = google_compute_network.hub.id
    cidr = local.hub_network_cidr
  }
}

output "spoke_primary_cidrs" {
  description = "Primary spoke CIDRs allocated by automated IPAM"
  value       = local.spoke_primary_cidrs
}

output "spoke_pod_cidrs" {
  description = "Pod secondary ranges allocated for GKE multi-cloud spokes"
  value       = local.spoke_pod_cidrs
}

output "spoke_service_cidrs" {
  description = "Service secondary ranges allocated for GKE multi-cloud spokes"
  value       = local.spoke_service_cidrs
}

output "spoke_gcve_cidrs" {
  description = "GCVE PSA ranges allocated for GCVE-enabled spokes"
  value       = local.spoke_gcve_cidrs
}

output "brownfield_referenced_networks" {
  description = "Legacy networks discovered through data sources"
  value = {
    for name, network in data.google_compute_network.referenced :
    name => {
      self_link = network.self_link
      project   = network.project
      name      = network.name
    }
  }
}

output "centralized_ingress_reserved_ips" {
  description = "Reserved global ingress IPs for spokes with centralized ingress enabled"
  value = {
    for name, ip in google_compute_global_address.centralized_ingress_ip :
    name => ip.address
  }
}

output "auto_corrected_features" {
  description = "Features dynamically bypassed by strict_free mode"
  value       = local.auto_corrected_features
}

output "default_injected_values" {
  description = "Default values used when optional YAML keys were absent"
  value       = local.default_injected_values
}

output "networking_complete" {
  description = "Networking status summary"
  value       = "Networking phase complete with managed spokes, brownfield references, and automated IPAM."
}
