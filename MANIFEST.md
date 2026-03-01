# 📦 Project Manifest - Complete File Reference

This document lists every file in the GCP Landing Zone project and explains its purpose.

---

## 📋 Root Level Files

### Documentation Files
- **README.md** - Main project overview (start here for big picture)
- **START_HERE.md** - "Layman's Map" & pre-flight checklist (read this first!)
- **DEPLOYMENT_GUIDE.md** - Step-by-step deployment walkthrough with troubleshooting
- **MANIFEST.md** - This file (complete reference of all files)

### Configuration Files
- **config.yaml** - 🔴 **MASTER CONTROL FILE** - All infrastructure is defined here
- **.gitignore** - Prevents committing sensitive files to git

### Automation Scripts
- **check_and_install.sh** - Verifies/installs gcloud, terraform, git (OS auto-detection)
- **bootstrap.sh** - Sets up foundation (auth, APIs, state bucket)
- **nuke.sh** - DESTROYS EVERYTHING (cleanup/cost stop)
- **run_all_phases.sh** - Automated deployment script (runs all 4 phases)

---

## 📁 Phase 0: Bootstrap

**Purpose:** Set up Terraform foundation (service account, APIs, state bucket)

**Cost:** $0 | **Time:** 3 minutes

### Files
- **0-Bootstrap/main.tf**
  - Creates Terraform service account
  - Enables required APIs
  - Creates GCS bucket for remote state
  - Creates landing zone folder

- **0-Bootstrap/variables.tf**
  - `enable_deletion_protection` - Protect critical resources
  - `terraform_state_retention_days` - How long to keep old states
  - `allow_sa_impersonation` - Allow terraform SA to impersonate others

- **0-Bootstrap/outputs.tf**
  - Service account email
  - Landing zone folder ID
  - Terraform state bucket name

- **0-Bootstrap/locals.tf** (auto-created by bootstrap.sh)
  - Reads config.yaml
  - Shares values with other phases

- **0-Bootstrap/backend-config.hcl** (auto-created by bootstrap.sh)
  - Tells Terraform where to store state in GCS

---

## 📁 Phase 1: Resource Manager (Resman)

**Purpose:** Create or import GCP projects (greenfield/brownfield)

**Cost:** $0 | **Time:** 5 minutes

### Files
- **1-Resman/main.tf**
  - Creates new projects (greenfield)
  - Imports existing projects (brownfield)
  - Assigns billing accounts
  - Enables APIs per project
  - Creates service accounts per project

- **1-Resman/variables.tf**
  - `terraform_state_bucket` - Link to state bucket
  - `auto_create_network` - Whether to create default networks
  - `enable_project_deletion_restrictions` - Add liens to prevent deletion

- **1-Resman/outputs.tf**
  - `spoke_projects` - Map of all project IDs
  - `greenfield_project_ids` - Newly created projects
  - `brownfield_project_ids` - Imported projects
  - `service_account_emails` - Default SA per project

- **1-Resman/locals.tf** (auto-created)
  - Same as Phase 0

- **1-Resman/backend-config.hcl** (auto-created)
  - Remote state configuration

---

## 📁 Phase 2: Networking

**Purpose:** Create Hub-and-Spoke VPC networks, peering, firewall rules

**Cost:** ~$10-50/month | **Time:** 10 minutes

### Files
- **2-Networking/main.tf**
  - Creates Hub VPC and subnet
  - Creates Spoke VPCs and subnets (one per project)
  - Sets up VPC Peering (hub ↔ spokes)
  - Creates firewall rules
  - Optional: Cloud NAT for internet egress

- **2-Networking/variables.tf**
  - `terraform_state_bucket` - Link to state
  - `enable_flow_logging` - Debug traffic logs
  - `enable_hub_nat` - Cloud NAT for private VMs
  - `bgp_asn` - For future HA VPN

- **2-Networking/outputs.tf**
  - `hub_network` - Hub VPC details
  - `hub_subnet` - Hub subnet CIDR
  - `spoke_networks` - All spoke VPC details
  - `spoke_subnets` - All spoke subnet CIDRs

- **2-Networking/locals.tf** (auto-created)
- **2-Networking/backend-config.hcl** (auto-created)

---

## 📁 Phase 3: Projects Configuration

**Purpose:** Security, logging, budgets, compliance, org policies

**Cost:** ~$5-20/month | **Time:** 5 minutes

### Files
- **3-Projects/main.tf**
  - Uses org-level APIs enabled in Phase 0
  - Creates budget alerts per spoke project
  - Sets up Cloud Logging (audit logs → BigQuery)
  - Enables Security Command Center (SCC) STANDARD free tier
  - Applies organizational policies (security guardrails)
  - Creates monitoring notification channels

- **3-Projects/variables.tf**
  - `alert_email` - Email for budget/monitoring alerts
  - `enable_resource_location_constraint` - Enforce regions (GDPR)
  - `allowed_regions` - Whitelist of regions

- **3-Projects/outputs.tf**
  - `audit_logs_dataset` - BigQuery dataset for logs
  - `budget_alerts_created` - Count of budgets
  - `org_policies_applied` - List of policies
  - `security_command_center` - SCC status

- **3-Projects/terraform.tfvars** - Optional variable overrides
  - `alert_email` - Override for alert email
  - `enable_resource_location_constraint` - Override for location constraint

- **3-Projects/locals.tf** (auto-created)
- **3-Projects/backend-config.hcl** (auto-created)

---

## 📊 File Dependencies

```
config.yaml
    ↓
check_and_install.sh (verify tools)
    ↓
bootstrap.sh (enables APIs, creates state bucket, creates locals.tf & backend-config.hcl)
    ↓
Phase 0: Bootstrap
  ├─ Creates service account
  ├─ Creates folder
  └─ Leaves outputs for Phase 1
    ↓
Phase 1: Resman
  ├─ Reads Phase 0 outputs (service account email, folder ID)
  ├─ Creates projects
  └─ Leaves outputs for Phase 2
    ↓
Phase 2: Networking
  ├─ Reads Phase 1 outputs (project IDs)
  ├─ Creates networks & peering
  └─ Leaves outputs for Phase 3
    ↓
Phase 3: Projects
  ├─ Reads Phase 1 & 2 outputs
  ├─ Configures security logging budgets
  └─ Done!
```

---

## 🔑 Key Files Explained

### config.yaml (THE MOST IMPORTANT!)
```yaml
organization_id: "123456789"        ← Your GCP Organization
billing_account: "000000-000000"    ← Your Billing Account
default_region: "us-central1"       ← Where infrastructure lives

spokes:                             ← Define your environments
  - name: "sandbox"
    type: "greenfield"              ← Create new OR import existing
    cost_profile: "free"            ← "free" or "paid" tier
    labels:
      env: "dev"                    ← For cost tracking
```

**⚠️ You MUST edit this!** Everything else is automated based on this file.

---

### START_HERE.md
- Layman's explanation of folder structure
- Where to find Organization ID & Billing Account ID
- Pre-flight checklist (IAM roles)
- Step-by-step instructions
- Troubleshooting tips
- Cost breakdown

**👉 Read this before running any scripts!**

---

### bootstrap.sh
```
STEP 1: Authenticate to Google Cloud
STEP 2: Enable APIs (with 30-second waits)
STEP 3: Create GCS state bucket
STEP 4: Create locals.tf for each phase
STEP 5: Create backend-config.hcl for each phase
```

**👉 Run this ONCE after editing config.yaml**

---

### run_all_phases.sh
Automates this workflow:
```
cd 0-Bootstrap && terraform init && terraform apply
cd 1-Resman && terraform init && terraform apply
cd 2-Networking && terraform init && terraform apply
cd 3-Projects && terraform init && terraform apply
```

**👉 Easier than running 4 phases manually**

---

### nuke.sh
Destroys everything:
```
- Removes project liens
- Runs terraform destroy in all phases
- Hunts orphaned resources
- Deletes all projects
- Deletes state bucket
```

**👉 Use this to STOP ALL COSTS**

---

## 📝 File Naming Conventions

| Pattern | Meaning |
|---------|---------|
| `*.tf` | Terraform configuration files |
| `*.tfvars` | Terraform variable overrides |
| `*.md` | Markdown documentation |
| `*.sh` | Bash shell scripts |
| `.gitignore` | Git ignore file (don't commit state, .terraform, etc) |
| `locals.tf` | Auto-created by bootstrap.sh (reads config.yaml) |
| `backend-config.hcl` | Auto-created by bootstrap.sh (state bucket config) |

---

## 🔍 File Size Targets

| File | Lines | Purpose |
|------|-------|---------|
| config.yaml | ~80 | Master control (easy to understand) |
| 0-Bootstrap/main.tf | ~200 | Service account, APIs, folder |
| 1-Resman/main.tf | ~150 | Projects creation/import |
| 2-Networking/main.tf | ~280 | HubAndSpoke networks |
| 3-Projects/main.tf | ~200 | Logging, budgets, policies |
| START_HERE.md | ~300 | Pre-flight guide |
| DEPLOYMENT_GUIDE.md | ~500 | Step-by-step deployment |
| README.md | ~400 | Project overview |

All files are heavily commented so they're easy to understand.

---

## ✅ Verification Checklist

After deployment, verify these files exist:

```bash
# Root level
ls -la START_HERE.md README.md config.yaml bootstrap.sh nuke.sh

# Phase 0
ls -la 0-Bootstrap/main.tf 0-Bootstrap/outputs.tf 0-Bootstrap/locals.tf

# Phase 1
ls -la 1-Resman/main.tf 1-Resman/outputs.tf 1-Resman/locals.tf

# Phase 2
ls -la 2-Networking/main.tf 2-Networking/outputs.tf 2-Networking/locals.tf

# Phase 3
ls -la 3-Projects/main.tf 3-Projects/terraform.tfvars 3-Projects/outputs.tf
```

All should exist (locals.tf and backend-config.hcl auto-created by bootstrap.sh).

---

## 📦 What NOT to Commit to Git

Based on .gitignore:
- ❌ `.terraform/` directories
- ❌ `terraform.tfstate` files
- ❌ `.terraform.lock.hcl` lock files
- ❌ `tfplan` files
- ❌ `credentials.json`
- ❌ `.env` files

All these are auto-generated or sensitive. Only commit:
- ✅ `.tf` files
- ✅ `.md` files
- ✅ `.sh` scripts
- ✅ `config.yaml` (but mask actual IDs before sharing!)

---

## 🚀 Quick Navigation

**I want to...**
- Learn what this project does → [README.md](README.md)
- Get started quickly → [START_HERE.md](START_HERE.md)
- See step-by-step deployment → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- Understand the file structure → [MANIFEST.md](MANIFEST.md) (this file)
- Explore a specific phase → Look in `0-Bootstrap/`, `1-Resman/`, `2-Networking/`, `3-Projects/`
- Configure everything → Edit [config.yaml](config.yaml)
- Clean up & stop costs → Run `./nuke.sh`

---

**File Count Summary:**
- 📖 Documentation: 4 files
- 🔧 Scripts: 4 files
- ⚙️ Config: 1 file
- 📦 Terraform: 16 files (4 phases × 4 files each)
- **Total: 25+ files**

All together = Complete, production-ready GCP infrastructure!

---

**Last Updated:** March 1, 2026  
**Terraform Version:** 1.5+  
**GCP Provider Version:** 5.0+
