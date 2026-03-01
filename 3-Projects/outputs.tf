# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 3 OUTPUTS                                                           ║
# ║  Purpose: Reports governance, budgets, and adaptive decisions.             ║
# ║  Why a layman needs this: Shows exactly what was applied and why.          ║
# ║  Cost Impact: $0 (outputs only).                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

output "budget_alerts_created" {
  description = "Number of budget policies created"
  value       = length(google_billing_budget.spoke_budgets)
}

output "scc_standard_state" {
  description = "SCC standard module status based on global_modules"
  value       = try(local.global_modules.enable_scc_standard, true) ? "enabled" : "disabled"
}

output "auto_corrected_features" {
  description = "Features bypassed by adaptive strict_free auto-corrector"
  value       = local.auto_corrected_features
}

output "default_injected_values" {
  description = "Defaults injected when optional YAML keys were missing"
  value       = local.default_injected_values
}

output "projects_complete" {
  description = "Status summary for projects phase"
  value       = "Projects phase complete. Budgets and governance settings are applied."
}
