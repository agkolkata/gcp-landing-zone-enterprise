# Prompt Compliance Report (2026-03-01)

## Scope
Comparison of current workspace implementation against the newly provided prompt requirements.

## Verdict
- Overall status: **Partially compliant**
- Blocking gaps: **8 critical**, **3 medium**

---

## Critical Gaps

1. Config template mismatch (required exact structure not implemented)
- Required: `global_modules`, `cost_mode`, `brownfield_reference`, `workload_foundations`.
- Found: `free_tier_modules`, `chargeable_modules`, and `cost_profile`.
- Evidence: `config.yaml:105`, `config.yaml:128`, `config.yaml:178`, `config.yaml:188`, `config.yaml:198`.

2. Ultimate mix-and-match behavior not supported as requested
- Required: strict free/custom mix per spoke (`cost_mode`) with granular blend.
- Found: global `has_free_tier_spokes` disables chargeable features for all spokes if any free spoke exists.
- Evidence: `2-Networking/main.tf:54`, `2-Networking/main.tf:57`, `2-Networking/main.tf:60`, `2-Networking/main.tf:63`, `2-Networking/main.tf:66`, `3-Projects/main.tf:61`.

3. Advanced brownfield handling incomplete
- Required: both `Adopt` (Terraform import blocks) and `Reference` (data sources for legacy networks).
- Found: only legacy brownfield project management (`type == "brownfield"`) and manual CLI import note; no Terraform `import {}` blocks and no network reference data sources.
- Evidence: `1-Resman/main.tf:69`, `1-Resman/main.tf:118`, `1-Resman/main.tf:121`.

4. Workload foundations missing
- Required toggles and scaffolding for GCVE, GKE/EKS multi-cloud, migration factory.
- Found: no corresponding config keys or Terraform resources.
- Evidence: no matches for `enable_gcve_networking`, `enable_gke_multi_cloud`, `enable_migration_factory` across repo.

5. Bootstrap API set incomplete vs prompt
- Required conditional APIs include `vmmigration.googleapis.com` and `gkehub.googleapis.com` when needed.
- Found: API array exists but those services are not present.
- Evidence: `bootstrap.sh:129` (API list declaration), no matches for `vmmigration.googleapis.com` or `gkehub.googleapis.com`.

6. Automated IPAM does not cover workload foundation ranges
- Required non-overlap for spoke subnets + GCVE + Kubernetes Pod/Service ranges.
- Found: only spoke CIDR automation implemented.
- Evidence: `2-Networking/main.tf` contains `cidrsubnet` for spokes only; no Pod/Service/GCVE subnet allocators.

7. Mandatory explanatory comment block missing in many Terraform files
- Required: every `.tf` file must include plain-English purpose, layman need, expected cost impact.
- Found: many files missing this block.
- Evidence sample: `2-Networking/main.tf`, `2-Networking/outputs.tf`, `3-Projects/observability.tf`, `3-Projects/vpc_service_controls.tf`, and most locals/variables/outputs files.

8. Zero-hardcoding requirement still not fully satisfied under strict reading
- Required: no hardcoded strings/IP ranges in `.tf`, everything derived from `config.yaml`.
- Found: static service list in VPC-SC and static monitoring thresholds/metric filters in Terraform.
- Evidence: `3-Projects/vpc_service_controls.tf:16`, `3-Projects/observability.tf` (dashboard/alert constants).

---

## Medium Gaps

1. `plan_and_scan.sh` does not include retry helper for API/network calls
- Required: all scripts include retry loops with exponential backoff for API calls.
- Found: retry loops in 3 scripts, not in `plan_and_scan.sh`.
- Evidence: no `retry_with_backoff` in `plan_and_scan.sh`.

2. Exact generated `config.yaml` template values differ from prompt
- Required exact snippet includes specific spokes (`enterprise-workloads`, `legacy-db-network`) and `global_modules` keys.
- Found different spoke names and schema.
- Evidence: `config.yaml` (entire structure differs).

3. Script executability requirement (`chmod +x`) not verifiable in this Windows workspace
- Required: 4 scripts executable.
- Found: scripts exist; executable-bit semantics are not authoritative on Windows filesystem.
- Evidence: files present at workspace root; POSIX mode not auditable here.

---

## Compliant Areas

1. START_HERE guide exists and includes layman map, pre-flight checklist, and VS Code terminal guidance.
- Evidence: `START_HERE.md:7`, `START_HERE.md:42`, `START_HERE.md:77`, `START_HERE.md:129`.

2. Provider pinning is compliant (`~> 5.0`) in phase main files.
- Evidence: `0-Bootstrap/main.tf:26`, `0-Bootstrap/main.tf:30`, `1-Resman/main.tf:25`, `2-Networking/main.tf:7`, `3-Projects/main.tf:27`.

3. Output transparency for auto-corrected/default-injected values exists.
- Evidence: `0-Bootstrap/outputs.tf:39`, `1-Resman/outputs.tf:47`, `2-Networking/outputs.tf:51`, `2-Networking/outputs.tf:56`, `3-Projects/outputs.tf:28`, `3-Projects/outputs.tf:33`.

4. `check_and_install.sh`, `bootstrap.sh`, and `nuke.sh` include exponential backoff retry helper.
- Evidence: `check_and_install.sh`, `bootstrap.sh`, `nuke.sh` all contain `retry_with_backoff`.

---

## Estimated Compliance
- Prompt-level compliance estimate: **~68%**

---

## Recommended Remediation Order
1. Replace control-plane schema to exact prompt (`global_modules`, `cost_mode`, `workload_foundations`, `brownfield_reference`).
2. Refactor auto-corrector from global free-spoke switch to per-spoke/per-feature logic.
3. Implement brownfield adopt/reference dual model (`import {}` + data sources).
4. Add workload foundation modules and API enablement gates (`vmmigration`, `gkehub`).
5. Extend IPAM allocator to GCVE + GKE secondary ranges with overlap guards.
6. Add mandatory layman/cost headers to every `.tf` file.
7. Add retry helper usage in `plan_and_scan.sh` for network/API operations.
