# 📊 Gap Analysis: Current Implementation vs New Prompt Requirements

## Status Update (March 1, 2026)

All 7 critical gaps listed in this report have now been implemented in the codebase.
This file is retained as a historical analysis record.

**Analysis Date:** March 1, 2026  
**Comparison:** Current codebase vs updated 2026 Google Cloud Architecture Framework requirements

---

## ✅ What's Already Compliant (Keep These)

| Requirement | Status | Location |
|------------|--------|----------|
| Provider pinning (~> 5.0) | ✅ Complete | All main.tf files |
| Plain-English documentation | ✅ Complete | All .tf files |
| START_HERE.md layman guide | ✅ Complete | [START_HERE.md](START_HERE.md) |
| check_and_install.sh | ✅ Complete | [check_and_install.sh](check_and_install.sh) |
| bootstrap.sh | ✅ Complete | [bootstrap.sh](bootstrap.sh) |
| plan_and_scan.sh (tfsec) | ✅ Complete | [plan_and_scan.sh](plan_and_scan.sh) |
| nuke.sh cleanup script | ✅ Complete | [nuke.sh](nuke.sh) |
| Budget alerts ($1/project) | ✅ Complete | [3-Projects/main.tf](3-Projects/main.tf) |
| Auto-tagging (FinOps labels) | ✅ Complete | locals.tf files |
| Identity-Aware Proxy (IAP) | ✅ Complete | [2-Networking/main.tf](2-Networking/main.tf) |
| Secret Manager | ✅ Complete | [2-Networking/main.tf](2-Networking/main.tf) |
| greenops_enforced | ✅ Complete | [0-Bootstrap/main.tf](0-Bootstrap/main.tf) |
| CIS Benchmark org policies | ✅ Complete | [3-Projects/main.tf](3-Projects/main.tf) |
| Free tier documentation | ✅ Complete | [FREE_TIER_SETUP.md](FREE_TIER_SETUP.md) |

---

## ❌ Critical Gaps (Must Implement)

### **GAP 1: Zero Hardcoding - 100% Configuration-Driven**

**Requirement:**
> "Absolutely NO hardcoded strings, IP ranges, project names, or regions in the `.tf` files. Every single variable MUST be derived dynamically from `config.yaml` or calculated via Terraform `locals`."

**Current State:**
- ❌ Hardcoded VPC name: `name = "hub-vpc"` in 2-Networking/main.tf
- ❌ Hardcoded subnet name: `name = "hub-subnet"`
- ❌ Hardcoded firewall rule names: `"hub-allow-internal"`, `"hub-allow-iap-tunnel"`
- ⚠️  Some naming patterns in locals but not all

**What Needs Fixing:**
```terraform
# CURRENT (BAD):
resource "google_compute_network" "hub" {
  name = "hub-vpc"  # ❌ Hardcoded
}

# REQUIRED (GOOD):
resource "google_compute_network" "hub" {
  name = "${local.environment_name}-${local.config.hub.name}-vpc"  # ✅ Dynamic
}
```

**Files to Update:**
- [2-Networking/main.tf](2-Networking/main.tf) - All resource names
- [1-Resman/main.tf](1-Resman/main.tf) - Project naming
- [3-Projects/main.tf](3-Projects/main.tf) - Budget/logging names

---

### **GAP 2: Automated IPAM (IP Address Management)**

**Requirement:**
> "Implement `cidrsubnet` logic so new spokes never overlap."

**Current State:**
- ❌ Manual `subnet_cidr` required in config.yaml for each spoke
- ❌ No automatic IP allocation
- ❌ User must manually calculate non-overlapping CIDRs

**What Needs Fixing:**
```yaml
# CURRENT (BAD - manual CIDRs):
spokes:
  - name: "sandbox"
    subnet_cidr: "10.1.0.0/20"  # ❌ User must calculate this
  - name: "production"
    subnet_cidr: "10.2.0.0/20"  # ❌ Must ensure no overlap

# REQUIRED (GOOD - auto-calculated):
spokes:
  - name: "sandbox"
    # No subnet_cidr needed - auto-calculated!
  - name: "production"
    # Auto-assigned from hub supernet
```

```terraform
# REQUIRED LOGIC:
locals {
  # Calculate spoke CIDRs automatically from hub supernet
  auto_spoke_cidrs = {
    for idx, spoke in local.config.spokes :
    spoke.name => cidrsubnet(local.config.hub.network_cidr, 4, idx + 1)
  }
}
```

**Files to Update:**
- [2-Networking/locals.tf](2-Networking/locals.tf) - Add IPAM logic
- [2-Networking/main.tf](2-Networking/main.tf) - Use auto-calculated CIDRs
- [config.yaml](config.yaml) - Remove subnet_cidr from spokes

**Benefit:** Users can add 100 spokes without calculating IPs manually!

---

### **GAP 3: Retry Loops with Exponential Backoff**

**Requirement:**
> "ALL scripts must be idempotent and include retry loops (e.g., try 3 times with exponential backoff) for any network or API calls"

**Current State:**
- ⚠️  bootstrap.sh has sleep delays but NO retry logic
- ❌ API enablement fails if propagation takes >30s
- ❌ No exponential backoff on failures

**What Needs Fixing:**
```bash
# CURRENT (BAD - no retries):
gcloud services enable compute.googleapis.com

# REQUIRED (GOOD - with retries):
retry_with_backoff() {
    local max_attempts=3
    local timeout=1
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        echo "Attempt $attempt failed. Retrying in ${timeout}s..."
        sleep $timeout
        timeout=$((timeout * 2))  # Exponential backoff
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Usage:
retry_with_backoff gcloud services enable compute.googleapis.com
```

**Files to Update:**
- [bootstrap.sh](bootstrap.sh) - Add retry_with_backoff function
- [check_and_install.sh](check_and_install.sh) - Wrap downloads in retries
- [nuke.sh](nuke.sh) - Retry deletion operations

**Benefit:** Scripts survive transient network failures!

---

### **GAP 4: The Seamless Cost Auto-Corrector**

**Requirement:**
> "If `cost_profile == "free"`, `locals` MUST silently force all chargeable features to `false`, overriding the YAML."

**Current State:**
- ❌ No automatic override logic
- ❌ User can enable Cloud NAT with cost_profile="free" (costs money!)
- ❌ No protection against accidental charges

**What Needs Fixing:**
```terraform
# REQUIRED LOGIC:
locals {
  # Auto-corrector: Force chargeable features OFF if ANY spoke uses "free" profile
  has_free_tier_spokes = contains([for s in local.config.spokes : s.cost_profile], "free")
  
  # Override chargeable modules
  enable_cloud_nat_corrected = local.has_free_tier_spokes ? false : try(local.config.chargeable_modules.enable_cloud_nat, false)
  
  enable_private_service_connect_corrected = local.has_free_tier_spokes ? false : try(local.config.chargeable_modules.enable_private_service_connect, false)
  
  enable_centralized_ingress_corrected = local.has_free_tier_spokes ? false : try(local.config.chargeable_modules.enable_centralized_ingress, false)
  
  # Track what was overridden for transparency
  auto_corrected_features = local.has_free_tier_spokes ? [
    "Cloud NAT disabled (cost_profile=free detected)",
    "Private Service Connect disabled (cost_profile=free detected)",
    "Centralized Ingress disabled (cost_profile=free detected)"
  ] : []
}

# Use corrected values:
resource "google_compute_router_nat" "hub_nat" {
  count = local.enable_cloud_nat_corrected ? 1 : 0  # ✅ Uses corrected value
  # ...
}
```

**Files to Update:**
- [2-Networking/locals.tf](2-Networking/locals.tf) - Add auto-corrector logic
- [2-Networking/main.tf](2-Networking/main.tf) - Use corrected values
- [3-Projects/locals.tf](3-Projects/locals.tf) - Add corrector for logging

**Benefit:** Impossible to accidentally enable paid features with free tier!

---

### **GAP 5: Output Transparency**

**Requirement:**
> "In `outputs.tf`, list any features that were dynamically bypassed or default-injected so the user is informed without experiencing an error."

**Current State:**
- ❌ No outputs.tf files showing auto-corrected features
- ❌ User has no visibility into what was overridden

**What Needs Fixing:**
```terraform
# NEW FILE NEEDED: 2-Networking/outputs.tf
output "auto_corrected_features" {
  description = "Features automatically disabled by cost auto-corrector"
  value       = local.auto_corrected_features
}

output "default_injected_values" {
  description = "YAML keys that were missing and got safe defaults"
  value = [
    for key, val in local.defaults_applied : 
    "${key} = ${val}"
  ]
}

output "cost_profile_summary" {
  description = "Cost profile impact analysis"
  value = {
    free_tier_spokes    = [for s in local.config.spokes : s.name if s.cost_profile == "free"]
    paid_tier_spokes    = [for s in local.config.spokes : s.name if s.cost_profile == "paid"]
    chargeable_features = local.enable_cloud_nat_corrected ? ["Cloud NAT ($35/mo)"] : []
  }
}
```

**Files to Create:**
- **NEW**: 2-Networking/outputs.tf
- **NEW**: 3-Projects/outputs.tf
- Update: 0-Bootstrap/outputs.tf
- Update: 1-Resman/outputs.tf

**Benefit:** Full transparency - users see exactly what was changed!

---

### **GAP 6: New Config Structure (free_tier_modules + chargeable_modules)**

**Requirement:**
> Generate config.yaml with split sections: `free_tier_modules` and `chargeable_modules`

**Current State:**
- ❌ Single `optional_modules` section (not split by cost)
- ❌ No clear visual separation of free vs paid

**What Needs Fixing:**
```yaml
# CURRENT (UNCLEAR):
optional_modules:
  enable_scc_standard: true        # Is this free?
  enable_cloud_nat: true           # This costs money!
  enable_iap_access: true          # Is this free?

# REQUIRED (CRYSTAL CLEAR):
# --- 100% FREE TIER SAFE MODULES ---
free_tier_modules:
  enable_scc_standard: true        # ✅ Always FREE
  enable_iap_access: true          # ✅ Always FREE
  enable_observability_baseline: true  # ✅ NEW - Always FREE

# --- CHARGEABLE ENTERPRISE MODULES ---
chargeable_modules:
  enable_cloud_nat: false          # ❌ $35+/month
  enable_private_service_connect: false  # ❌ $50+/month
  enable_centralized_ingress: false      # ❌ NEW - $50+/month
  enable_egress_inspection: false        # ❌ NEW - $100+/month
  enable_vpc_service_controls: false     # ❌ NEW - $0 but complexity
```

**Files to Update:**
- [config.yaml](config.yaml) - Restructure modules
- All locals.tf - Read from new structure

**Benefit:** Impossible to confuse free vs paid features!

---

### **GAP 7: New Enterprise Modules**

**Requirement:**
Add 4 new modules per 2026 Google Cloud Architecture Framework:

| Module | Purpose | Cost | Implementation |
|--------|---------|------|---------------|
| `enable_observability_baseline` | Cloud Monitoring dashboards + alerting | 🟢 FREE | NEW |
| `enable_centralized_ingress` | Global Load Balancer + Cloud Armor | 🔴 $50+/mo | NEW |
| `enable_egress_inspection` | Cloud NGFW for outbound traffic filtering | 🔴 $100+/mo | NEW |
| `enable_vpc_service_controls` | VPC Service Controls perimeter | 🟢 FREE (complexity) | NEW |

**Current State:**
- ❌ None of these modules exist

**What Needs Adding:**

#### **1. enable_observability_baseline** (FREE)
```terraform
# NEW: 3-Projects/observability.tf
resource "google_monitoring_dashboard" "spoke_dashboards" {
  for_each = local.spokes_map
  
  dashboard_json = jsonencode({
    displayName = "${each.key} Monitoring Dashboard"
    # ... widgets for CPU, memory, disk, network
  })
}

resource "google_monitoring_alert_policy" "high_cpu" {
  # Alert if CPU > 80% for 5 minutes
}
```

#### **2. enable_centralized_ingress** (CHARGEABLE)
```terraform
# NEW: 2-Networking/ingress.tf
resource "google_compute_global_forwarding_rule" "ingress" {
  count = local.enable_centralized_ingress_corrected ? 1 : 0
  
  # Global LB with Cloud Armor attached
}
```

#### **3. enable_egress_inspection** (CHARGEABLE)
```terraform
# NEW: 2-Networking/egress_inspection.tf
resource "google_network_security_gateway_security_policy" "egress" {
  count = local.enable_egress_inspection_corrected ? 1 : 0
  
  # Cloud NGFW for egress filtering
}
```

#### **4. enable_vpc_service_controls** (FREE but complex)
```terraform
# NEW: 3-Projects/vpc_service_controls.tf
resource "google_access_context_manager_service_perimeter" "spoke_perimeters" {
  count = local.enable_vpc_service_controls ? 1 : 0
  
  # Perimeter around sensitive services
}
```

**Files to Create:**
- **NEW**: 3-Projects/observability.tf
- **NEW**: 2-Networking/ingress.tf
- **NEW**: 2-Networking/egress_inspection.tf
- **NEW**: 3-Projects/vpc_service_controls.tf

---

## 📋 Summary: Action Items

### **High Priority (Breaking Changes)**
1. ❌ **Zero Hardcoding**: Remove all hardcoded names/IPs (affects all .tf files)
2. ❌ **Automated IPAM**: Implement cidrsubnet logic (affects config.yaml + 2-Networking)
3. ❌ **Config Restructure**: Split free_tier_modules + chargeable_modules (breaking config.yaml change)

### **Medium Priority (Enhancements)**
4. ❌ **Cost Auto-Corrector**: Add override logic (prevents accidental charges)
5. ❌ **Output Transparency**: Create outputs.tf files (visibility)
6. ❌ **Retry Loops**: Add exponential backoff (resilience)

### **Low Priority (New Features)**
7. ❌ **New Modules**: Add 4 enterprise modules (extends capabilities)

---

## 💡 Recommendation

**Option 1: Full Compliance (7-10 hours work)**
- Implement all 7 gaps
- Breaking changes to config.yaml (users must migrate)
- Fully aligned with 2026 Google Cloud Architecture Framework

**Option 2: Prioritized Approach (3-4 hours work)**
- Implement GAP 4 (Cost Auto-Corrector) - highest user value
- Implement GAP 5 (Output Transparency) - easy win
- Implement GAP 3 (Retry Loops) - stability improvement
- Defer GAP 1, 2, 6, 7 to v2.0

**Option 3: Keep Current + Add Protection (1 hour work)**
- Only implement Cost Auto-Corrector
- Document other gaps in ROADMAP.md
- Mark current version as "v1.0 (2025 Framework compliant)"

---

## 🎯 Your Decision

**Which approach do you prefer?**

Type:
- **"implement all"** → Full compliance (7-10 hours)
- **"implement priority"** → Critical 3 gaps only (3-4 hours)  
- **"add protection only"** → Just cost auto-corrector (1 hour)

I'll proceed immediately with your chosen option.

---

**Last Updated:** March 1, 2026  
**Analysis Version:** 2.0
