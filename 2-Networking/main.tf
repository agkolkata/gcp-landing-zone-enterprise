# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 2: NETWORKING                                                       ║
# ║  Purpose: Builds hub-and-spoke networking with brownfield reference peers, ║
# ║  workload foundations, and automated non-overlapping IPAM.                 ║
# ║  Why a layman needs this: Networks must be connected safely before apps.   ║
# ║  Cost Impact: VPC itself is low-cost; NAT/VPN/GCVE features are chargeable.║
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

locals {
  hub_network_cidr = local.config.hub.network_cidr
  hub_name         = local.config.hub.name
  hub_vpc_name     = "${local.hub_name}-vpc"
  hub_subnet_name  = "${local.hub_name}-subnet"

  managed_spokes = {
    for idx, spoke in local.spokes :
    spoke.name => merge(spoke, { index = idx })
    if spoke.type != "brownfield_reference"
  }

  reference_spokes = {
    for spoke in local.spokes :
    spoke.name => spoke
    if spoke.type == "brownfield_reference"
  }

  # IPAM strategy: allocate 4 non-overlapping /26 slices per spoke from hub CIDR.
  # index*4+0 -> primary subnet, +1 -> pods, +2 -> services, +3 -> gcve.
  spoke_primary_cidrs = {
    for name, spoke in local.managed_spokes :
    name => cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4)
  }

  spoke_pod_cidrs = {
    for name, spoke in local.managed_spokes :
    name => cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 1)
  }

  spoke_service_cidrs = {
    for name, spoke in local.managed_spokes :
    name => cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 2)
  }

  spoke_gcve_cidrs = {
    for name, spoke in local.managed_spokes :
    name => cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 3)
  }

  spoke_effective = {
    for name, spoke in local.managed_spokes :
    name => {
      cost_mode             = try(spoke.cost_mode, "custom_mix")
      strict_free           = try(spoke.cost_mode, "custom_mix") == "strict_free"
      enable_nat            = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(local.global_modules.enable_cloud_nat, false)
      enable_centralized_ingress = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(local.config.advanced_modules.enable_centralized_ingress, false)
      enable_hybrid         = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(local.global_modules.enable_hybrid_connectivity, false)
      enable_gcve_network   = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(spoke.workload_foundations.enable_gcve_networking, false)
      enable_gke_multicloud = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(spoke.workload_foundations.enable_gke_multi_cloud, false)
      enable_migration      = try(spoke.cost_mode, "custom_mix") == "strict_free" ? false : try(spoke.workload_foundations.enable_migration_factory, false)
    }
  }

  enable_cloud_nat_hub = anytrue([for _, state in local.spoke_effective : state.enable_nat])

  auto_corrected_features = flatten([
    for name, state in local.spoke_effective : state.strict_free ? [
      "${name}: enable_cloud_nat forced false",
      "${name}: enable_centralized_ingress forced false",
      "${name}: enable_hybrid_connectivity forced false",
      "${name}: enable_gcve_networking forced false",
      "${name}: enable_gke_multi_cloud forced false",
      "${name}: enable_migration_factory forced false"
    ] : []
  ])

  default_injected_values = []
}

resource "terraform_data" "validate_ipam_capacity" {
  lifecycle {
    precondition {
      condition     = length(local.managed_spokes) <= 16
      error_message = "IPAM limit reached for current hub CIDR strategy. Reduce spokes or increase hub CIDR size."
    }

    precondition {
      condition = alltrue([
        for _, spoke in local.managed_spokes :
        can(cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4)) &&
        can(cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 1)) &&
        can(cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 2)) &&
        can(cidrsubnet(local.hub_network_cidr, 6, spoke.index * 4 + 3))
      ])
      error_message = "hub.network_cidr is incompatible with current IPAM slicing strategy. Use a larger CIDR block."
    }
  }
}

resource "google_compute_network" "hub" {
  name                    = local.hub_vpc_name
  project                 = local.org_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "hub" {
  name          = local.hub_subnet_name
  project       = local.org_id
  region        = local.default_region
  network       = google_compute_network.hub.id
  ip_cidr_range = local.hub_network_cidr
}

resource "google_compute_network" "spokes" {
  for_each = local.managed_spokes

  name                    = "${each.key}-vpc"
  project                 = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "spokes" {
  for_each = local.managed_spokes

  name          = "${each.key}-subnet"
  project       = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  region        = local.default_region
  network       = google_compute_network.spokes[each.key].id
  ip_cidr_range = local.spoke_primary_cidrs[each.key]

  dynamic "secondary_ip_range" {
    for_each = local.spoke_effective[each.key].enable_gke_multicloud ? {
      pods     = local.spoke_pod_cidrs[each.key]
      services = local.spoke_service_cidrs[each.key]
    } : {}

    content {
      range_name    = "${each.key}-${secondary_ip_range.key}"
      ip_cidr_range = secondary_ip_range.value
    }
  }

  depends_on = [terraform_data.validate_ipam_capacity]
}

resource "google_compute_network_peering" "hub_to_spokes" {
  for_each = local.managed_spokes

  name         = "hub-to-${each.key}"
  network      = google_compute_network.hub.self_link
  peer_network = google_compute_network.spokes[each.key].self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "spokes_to_hub" {
  for_each = local.managed_spokes

  name         = "${each.key}-to-hub"
  network      = google_compute_network.spokes[each.key].self_link
  peer_network = google_compute_network.hub.self_link

  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.hub_to_spokes]
}

# Brownfield reference: read legacy VPCs via data sources only (no management).
data "google_compute_network" "referenced" {
  for_each = local.reference_spokes

  project = element(split("/", each.value.existing_network_id), 1)
  name    = element(split("/", each.value.existing_network_id), 4)
}

resource "google_compute_network_peering" "hub_to_referenced" {
  for_each = data.google_compute_network.referenced

  name         = "hub-to-${each.key}-reference"
  network      = google_compute_network.hub.self_link
  peer_network = each.value.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_firewall" "hub_allow_iap" {
  count = try(local.global_modules.enable_iap_access, true) ? 1 : 0

  name    = "${local.hub_name}-allow-iap"
  network = google_compute_network.hub.name
  project = local.org_id

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = local.config.hub.iap_source_ranges
}

resource "google_compute_router" "hub" {
  count   = local.enable_cloud_nat_hub ? 1 : 0
  name    = "${local.hub_name}-router"
  region  = local.default_region
  project = local.org_id
  network = google_compute_network.hub.id

  bgp {
    asn = var.bgp_asn
  }
}

resource "google_compute_router_nat" "hub" {
  count                  = local.enable_cloud_nat_hub ? 1 : 0
  name                   = "${local.hub_name}-nat"
  router                 = google_compute_router.hub[0].name
  region                 = google_compute_router.hub[0].region
  nat_ip_allocate_option = "AUTO_ONLY"

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Workload foundation: GCVE networking scaffold using PSA reserved range.
resource "google_compute_global_address" "gcve_psa" {
  for_each = {
    for name, state in local.spoke_effective :
    name => state
    if state.enable_gcve_network
  }

  project       = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  name          = "${each.key}-gcve-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.spokes[each.key].id
}

resource "google_service_networking_connection" "gcve_psa" {
  for_each = google_compute_global_address.gcve_psa

  network                 = google_compute_network.spokes[each.key].id
  service                 = local.config.service_catalog.service_networking_api
  reserved_peering_ranges = [each.value.name]
}

# Chargeable centralized ingress scaffold (global load balancer public IP reservation).
resource "google_compute_global_address" "centralized_ingress_ip" {
  for_each = {
    for name, state in local.spoke_effective :
    name => state
    if state.enable_centralized_ingress
  }

  project = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  name    = "${each.key}-centralized-ingress-ip"
}

# Workload foundation: migration factory ingress baseline.
resource "google_compute_firewall" "migration_factory_ingress" {
  for_each = {
    for name, state in local.spoke_effective :
    name => state
    if state.enable_migration
  }

  name    = "${each.key}-migration-factory-ingress"
  network = google_compute_network.spokes[each.key].name
  project = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "3389"]
  }

  source_ranges = [local.hub_network_cidr]
}

# Global hybrid connectivity scaffold, auto-corrected off for strict_free spokes.
resource "google_compute_vpn_gateway" "spoke_hybrid" {
  for_each = {
    for name, state in local.spoke_effective :
    name => state
    if state.enable_hybrid
  }

  project = data.terraform_remote_state.resman.outputs.spoke_projects[each.key].project_id
  name    = "${each.key}-hybrid-vpn-gw"
  region  = local.default_region
  network = google_compute_network.spokes[each.key].id
}
