# Purpose: Input options for network telemetry and routing behavior.
# Why a layman needs this: Lets you toggle optional networking behavior safely.
# Cost Impact: Flow logs/NAT settings may increase networking charges.

variable "enable_flow_logging" {
  description = "Enable VPC Flow Logs (for debugging traffic - increases logs)"
  type        = bool
  default     = false
}

variable "enable_hub_nat" {
  description = "Enable Cloud NAT on hub router (for VMs with no public IPs to reach internet)"
  type        = bool
  default     = true
}

variable "bgp_asn" {
  description = "BGP ASN for hub router (in case you add HA VPN later)"
  type        = number
  default     = 64514
}
