# Purpose: Input options for notifications and policy scope.
# Why a layman needs this: Controls who receives alerts and where policies apply.
# Cost Impact: Email channel is low cost; monitoring/alerts may incur usage costs.

variable "alert_email" {
  description = "Email address for budget and monitoring alerts"
  type        = string
  default     = ""
  # Example: "admin@company.com"
}

variable "enable_resource_location_constraint" {
  description = "Restrict resources to specific regions for data residency"
  type        = bool
  default     = false
}

variable "allowed_regions" {
  description = "List of allowed regions (for data residency compliance)"
  type        = list(string)
  default     = []
}

variable "access_context_manager_policy_id" {
  description = "Numeric Access Context Manager policy ID used for VPC Service Controls"
  type        = string
  default     = ""
}
