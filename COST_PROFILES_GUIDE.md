# 💰 Cost Profiles Guide

This guide explains how to use the cost profiles (FREE vs PAID) in your landing zone.

---

## What Are Cost Profiles?

Cost profiles are **templates** that define recommended resource sizes based on budget tier:

| Aspect | FREE Profile | PAID Profile |
|--------|--------------|--------------|
| **VM Size** | `e2-micro` | `e2-standard-2` |
| **Disk Size** | 20 GB | 50 GB |
| **Region** | `us-central1` only | Any region |
| **Network Tier** | Standard (cheaper) | Premium (faster) |
| **HA VPN** | ❌ No | ✅ Yes |
| **Cloud Armor** | ❌ No (no DDoS protection) | ✅ Yes (DDoS protection) |
| **Est. Monthly Cost** | $0-10 | $50-200+ |

---

## How to Use Cost Profiles

### In config.yaml

Each spoke defines a cost profile:

```yaml
spokes:
  - name: "sandbox"
    cost_profile: "free"      # ← Choose here
    labels:
      env: "dev"

  - name: "production"
    cost_profile: "paid"      # ← Or here
    labels:
      env: "prod"
```

---

## What the Cost Profiles Control

### FREE Profile (Intended for Development/Testing)

Forces these restrictions:
```yaml
cost_profiles:
  free:
    vm_machine_type: "e2-micro"          # Small VM (free tier)
    disk_size_gb: 20                     # Small disk
    network_tier: "STANDARD"             # Cheaper data transfer
    region_override: "us-central1"       # FREE tier region only
    enable_ha_vpn: false                 # ❌ HA not needed for dev
    enable_cloud_armor: false            # ❌ DDoS protection not needed
```

**Meaning:**
- Tier 1: Your first 730 hours/month of e2-micro are **FREE** on GCP
- Networking: Standard tier is ~$0.025/GB vs Premium's $0.04/GB
- No advanced features (HA, DDoS)

**Best For:**
- Development environments
- Testing infrastructure
- Learning GCP
- Cost-conscious teams

---

### PAID Profile (Intended for Production)

Enables enterprise features:
```yaml
cost_profiles:
  paid:
    vm_machine_type: "e2-standard-2"     # More powerful
    disk_size_gb: 50                     # Bigger disk
    network_tier: "PREMIUM"              # Better performance + HA
    region_override: null                # Any region allowed
    enable_ha_vpn: true                  # ✅ High-Availability
    enable_cloud_armor: true             # ✅ DDoS protection
```

**Meaning:**
- Machine: More RAM, CPU for production workloads
- Networking: Premium tier means better global routing
- HA VPN: Automatic failover, no downtime
- Cloud Armor: DDoS mitigation (blocks attacks)

**Best For:**
- Production applications
- Customer-facing services
- Compliance requirements
- High-availability needs

---

## Enforcing Cost Profiles in Your Spoke

### Option 1: Manual Enforcement (Current Approach)

When you deploy infrastructure, manually check config.yaml and set resource sizes accordingly:

**If cost_profile="free":**
```bash
# When creating VM:
gcloud compute instances create my-vm \
  --machine-type=e2-micro \
  --zone=us-central1-a \
  --boot-disk-size=20GB

# When creating network:
gcloud compute networks create slack-vpc --subnet-mode=custom
gcloud compute networks subnets create slack-subnet \
  --network=slack-vpc \
  --range=10.1.0.0/20 \
  --region=us-central1    # MUST be us-central1 for free
```

**If cost_profile="paid":**
```bash
# When creating VM:
gcloud compute instances create my-vm \
  --machine-type=e2-standard-2 \
  --zone=us-central1-a \    # Can be any region
  --boot-disk-size=50GB

# Enable Cloud Armor (if needed):
gcloud compute security-policies create prod-policy
gcloud compute backend-services update my-backend \
  --security-policy=prod-policy
```

---

### Option 2: Terraform Enforcement (Advanced)

To automatically enforce cost profiles in Terraform, add this logic to your spoke VM creation:

**In 3-Projects/main.tf**, add a spoke-specific cost resource:

```terraform
# Example: Create VM per spoke with cost profile
resource "google_compute_instance" "spoke_vm" {
  for_each = local.spokes_map

  name         = "${each.key}-vm"
  project      = local.resman_output.spoke_projects[each.key].project_id
  zone         = "${local.default_region}-a"

  # Cost Profile Enforcement
  machine_type = local.config.cost_profiles[each.value.cost_profile].vm_machine_type
  # Expands to: "e2-micro" for free, "e2-standard-2" for paid

  boot_disk {
    initialize_params {
      size = local.config.cost_profiles[each.value.cost_profile].disk_size_gb
      # Expands to: 20 for free, 50 for paid
    }
  }

  network_interface {
    network            = google_compute_network.spokes[each.key].id
    network_ip         = "10.${index(keys(local.spokes_map), each.key) + 1}.0.2"
    network_tier       = local.config.cost_profiles[each.value.cost_profile].network_tier
    # Expands to: "STANDARD" for free, "PREMIUM" for paid
  }

  labels = each.value.labels
}
```

---

## Real-World Examples

### Scenario 1: Development-Only Landing Zone

**Goal:** Minimize costs for testing infrastructure

```yaml
# config.yaml
spokes:
  - name: "sandbox"
    cost_profile: "free"        # All free
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "staging"
    cost_profile: "free"        # Also free
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "dev-test"
    cost_profile: "free"        # All free
    # subnet_cidr auto-assigned by Terraform IPAM

hub:
  enable_nat: true              # Let VMs reach internet
```

**Expected Cost:**
```
Phase 0-1: $0 (projects, setup)
Phase 2: ~$5/month (networking, NAT)
Phase 3: ~$3/month (logging, budgets)
Total: ~$8/month (if using e2-micro free tier)
```

---

### Scenario 2: Production-Ready Landing Zone

**Goal:** Enterprise features for production apps

```yaml
# config.yaml
spokes:
  - name: "sandbox"
    cost_profile: "free"        # Dev/test still cheap
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "production"
    cost_profile: "paid"        # Production gets premium
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "analytics"
    cost_profile: "paid"        # Data workloads need power
    # subnet_cidr auto-assigned by Terraform IPAM

hub:
  enable_nat: true
```

**Expected Cost:**
```
Production spoke:
  - e2-standard-2 VM: ~$30/month
  - Premium tier networking: ~$15/month
  - Cloud Armor: ~$5/month
  - Logging: ~$10/month
  Subtotal: ~$60/month

Free scope (sandbox):
  - e2-micro: ~$0 (free tier)
  - Subtotal: ~$0

Total: ~$60/month for 2 spokes
```

---

### Scenario 3: Mixed Profile Landing Zone

**Goal:** Balance cost and features

```yaml
spokes:
  - name: "sandbox"
    cost_profile: "free"        # Testing = cheap
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "api-server"
    cost_profile: "paid"        # Customer-facing = features
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "internal-tools"
    cost_profile: "free"        # Internal = can be basic
    # subnet_cidr auto-assigned by Terraform IPAM

  - name: "db-processing"
    cost_profile: "paid"        # Heavy compute = bigger machine
    # subnet_cidr auto-assigned by Terraform IPAM
```

---

## Cost Profile Checklist

### Before Deploying FREE Profile Spoke:

- ✅ Is this for dev/testing only?
- ✅ Can you tolerate 20 GB disk?
- ✅ Do you only need us-central1?
- ✅ No DDoS attacks expected?
- ✅ No HA requirements?

If YES to all → Use FREE profile

### Before Deploying PAID Profile Spoke:

- ✅ Is this production?
- ✅ Do you need more than 20 GB?
- ✅ Do you need multiple regions?
- ✅ Do you need DDoS protection?
- ✅ Do you have SLA requirements?

If YES to any → Use PAID profile

---

## Switching Cost Profiles

### From FREE → PAID

```bash
# 1. Update config.yaml
spokes:
  - name: "sandbox"
    cost_profile: "free"
  - name: "production"
    cost_profile: "paid"   # ← Changed from "free"

# 2. Redeploy (or manually update resources)
cd 3-Projects && terraform plan
# Should show VM machine type changed to e2-standard-2

# 3. If you have existing VMs, delete and recreate:
gcloud compute instances delete old-vm --zone us-central1-a
gcloud compute instances create new-vm \
  --machine-type=e2-standard-2 \
  --zone=your-preferred-zone
```

### From PAID → FREE

⚠️ **Warning:** Downgrading might cause resource constraints.

```bash
# 1. Check if spoke actually needs paid features
# 2. If not, set to free
# 3. Be aware:
#    - Larger disks can't fit on e2-micro boot
#    - Premium tier resources can't downgrade to standard
#    - Better to keep as is if already using paid
```

---

## Monitoring Cost Profile Usage

### Check Current Costs by Spoke

```bash
# In Cloud Console:
# 1. Go to Billing → Reports
# 2. Filter by: Deployed on {spoke-name} label
# 3. See actual spend vs cost profile estimate
```

### Set Budget Alerts Per Spoke

```bash
# Cost profiles automatically create $1/month budgets
# To see them:
gcloud billing budgets list --billing-account=YOUR_BILLING_ID

# Expected output:
# NAME            | LIMIT      | % SPENT
# sandbox-budget  | $1.00      | 0%
# production-budget | $1.00    | 0%
```

---

## Tips to Stay in Budget

### For FREE Profile:
- ✅ Use e2-micro VMs (first 730 hrs/month = free)
- ✅ Keep data in us-central1 (free tier region)
- ✅ Use standard networking tier
- ✅ Delete unused resources immediately
- ✅ Set aggressive budget alerts ($0.50/month)

### For PAID Profile:
- ✅ Right-size VMs (e2-standard-2 is not always needed)
- ✅ Use preemptible VMs for non-critical workloads (-70% cost)
- ✅ Enable Cloud Armor only if DDoS risk is real
- ✅ Monitor actual usage for 3 months
- ✅ Adjust machine types based on utilization

---

## Future Enhancement: Auto-Enforcement

Currently, cost profiles are **defined** in config.yaml but the Terraform code doesn't automatically enforce them.

**Planned for v2:**
```terraform
# Future: Automatic enforcement in each phase
data "google_compute_machine_types" "spoke" {
  project = each.value.project_id
  zone    = "${local.default_region}-a"

  filter = local.config.cost_profiles[each.value.cost_profile].vm_machine_type
}

# This would force the right machine type based on cost profile
```

---

## FAQ

**Q: Can I use a FREE profile VM but in europe-west1?**
A: No - FREE profile forces `region_override: "us-central1"`. Must use paid for other regions.

**Q: What if I start PAID then want to switch to FREE?**
A: It's complex (can't downgrade disk sizes). Better to keep as PAID if you started that way.

**Q: Does cost profile affect storage costs?**
A: Yes - both have storage, but differences are small (~$0.02/GB). Logging is main variable cost.

**Q: Can I have different cost profiles per PROJECT but same SPOKE?**
A: No - cost profile is per spoke. Each spoke is its own project.

**Q: What's the biggest cost driver?**
A: VM compute time (hourly rate). Second is data egress (per GB).

---

For more, see:
- [config.yaml](config.yaml) - Cost profile definitions
- [README.md](README.md) - Architecture overview
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - One-page cheat sheet

