# terraform.tfvars - Phase 3
# Optional configuration for Phase 3: Projects

# Email address where budget & monitoring alerts should be sent
# Leave empty ("") to skip email alerts
alert_email = "admin@company.com"

# Whether to enforce resource location constraints (for data residency)
# Set to true if you need all resources in specific regions (e.g., EU for GDPR)
enable_resource_location_constraint = false

# Allowed regions for resources (only used if enable_resource_location_constraint = true)
# Example: ["europe-west1", "europe-west4"]
allowed_regions = []
