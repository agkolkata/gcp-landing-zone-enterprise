# Purpose: Input toggles for project lifecycle safeguards.
# Why a layman needs this: Controls project safety defaults during deployment.
# Cost Impact: $0 (input-only variables).

variable "auto_create_network" {
  description = "Whether GCP should auto-create default networks (usually false for security)"
  type        = bool
  default     = false
}

variable "enable_project_deletion_restrictions" {
  description = "Add liens to prevent accidental project deletion"
  type        = bool
  default     = true
}
