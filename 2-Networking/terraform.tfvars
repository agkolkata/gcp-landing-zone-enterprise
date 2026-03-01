# terraform.tfvars - Phase 2: Networking

# Whether to enable VPC Flow Logs (logs all traffic - increases logging costs)
enable_flow_logging = false

# Whether to enable Cloud NAT on the hub router (allows private VMs to reach internet)
enable_hub_nat = true

# BGP ASN for the hub router (used if you add HA VPN later)
bgp_asn = 64514
