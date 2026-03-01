# Purpose: Input toggles for bootstrap safety behaviors.
# Why a layman needs this: Helps prevent accidental destructive changes.
# Cost Impact: $0 (input-only variables).

variable "enable_deletion_protection" {
  description = "Prevent accidental deletion of critical resources"
  type        = bool
  default     = true
}

variable "terraform_state_retention_days" {
  description = "How many days to keep old state file versions"
  type        = number
  default     = 30
}

variable "allow_sa_impersonation" {
  description = "Allow the Terraform service account to impersonate other service accounts"
  type        = bool
  default     = true
}
