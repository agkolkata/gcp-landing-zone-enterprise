# 🏗️ GCP Hub-and-Spoke Landing Zone (Enterprise Edition)

**Production-ready Infrastructure-as-Code for Google Cloud Platform**

A complete, fully-automated Blueprint for deploying a secure, scalable, and cost-optimized Hub-and-Spoke network architecture on GCP.

---

## 💰 **Cost-Conscious? Read This First!**

**Want to deploy for $0/month?** → See **[FREE_TIER_SETUP.md](FREE_TIER_SETUP.md)** for pure free tier configuration.

**Quick Cost Decision Table:**

| Your Goal | Monthly Cost | What to Read |
|-----------|-------------|--------------|
| 🟢 **Learning/Testing (Free)** | **$0** | [FREE_TIER_SETUP.md](FREE_TIER_SETUP.md) |
| 🟡 **Small Business (Basic)** | **~$8** | [START_HERE.md](START_HERE.md) |
| 🔴 **Enterprise (HA)** | **~$150** | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) |

**What's Always FREE (No Charges Ever):**
- ✅ 1x e2-micro VM (24/7 in us-central1)
- ✅ 30GB persistent disk
- ✅ Security Command Center (SCC) scanning
- ✅ Identity-Aware Proxy (Zero Trust VM access)
- ✅ Hub-Spoke VPC networking & peering
- ✅ Org Policies (security guardrails)

**What COSTS Money (Disable in config.yaml for Free Tier):**
- ❌ `enable_central_logging: true` → $7/month (BigQuery audit logs)
- ❌ `enable_cloud_nat: true` → $35/month (outbound internet for private VMs)
- ❌ `enable_private_service_connect: true` → $50/month (private API endpoints)
- ❌ `enable_secret_manager: true` → $1/month (password vault)

**💡 To stay FREE:** Set all the above to `false` in [config.yaml](config.yaml) and use only 1 spoke with `cost_profile: "free"`.

---

## 📌 What is This?

This is a complete, **turn-key** GCP infrastructure template based on [Google Cloud Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric). It includes:

✅ **Hub-and-Spoke VPC Architecture** - Central hub with multiple isolated spokes  
✅ **Multi-Project Setup** - Separate projects for dev, prod, analytics (billing isolation)  
✅ **Greenfield + Brownfield Support** - Create new or import existing projects  
✅ **Enterprise Security** - Org policies, audit logging, SCC scanning  
✅ **Cost Control** - Auto budget alerts, tag-based cost allocation  
✅ **FinOps-Ready** - Built-in labeling, cost profiles (free vs. paid)  
✅ **"Layman-Friendly"** - Well-commented code, deployment guides, no Terraform experience needed  

---

## 🎯 Key Features

| Feature | Benefit |
|---------|---------|
| **Config-Driven Everything** | Single `config.yaml` controls entire infrastructure |
| **Free Tier Optimization** | "free" profile forces us-central1, e2-micro (alllows $0-5 billing) |
| **Auto Cleanup** | `nuke.sh` destroys EVERYTHING to stop costs immediately |
| **Remote State** | GCS bucket stores Terraform backups safely |
| **Modular Design** | 4 independent Terraform phases (can deploy incrementally) |
| **Hands-Off Setup** | `bootstrap.sh` auto-detects OS, installs deps, enables APIs in sequence |
| **Audit Ready** | BigQuery logging, org policies, SCC for compliance reporting |

---

## 📁 Directory Structure

```
GCP-LANDING-ZONE-ENT-1/
│
├── 📖 START_HERE.md (← START HERE!)
├── 📋 README.md (you are here)
├── 🚀 DEPLOYMENT_GUIDE.md (step-by-step walkthrough)
├── ⚙️  config.yaml (MASTER CONTROL FILE - edit this!)
│
├── 🔧 SCRIPTS
├── ├── check_and_install.sh (verify/install gcloud, terraform, git)
├── ├── bootstrap.sh (enable APIs, create state bucket)
├── ├── nuke.sh (delete EVERYTHING, stop all costs)
├── └── run_all_phases.sh (auto-deploy all phases)
│
├── 📁 0-Bootstrap/ (Phase 0)
│   ├── main.tf (service account, APIs, folder)
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf (auto-created by bootstrap.sh)
│
├── 📁 1-Resman/ (Phase 1)
│   ├── main.tf (create/import projects)
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf (auto-created)
│
├── 📁 2-Networking/ (Phase 2)
│   ├── main.tf (hub VPC, spoke VPCs, peering)
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf (auto-created)
│
└── 📁 3-Projects/ (Phase 3)
    ├── main.tf (logging, budgets, org policies, security)
    ├── variables.tf
    ├── terraform.tfvars (optional config)
    ├── outputs.tf
    └── locals.tf (auto-created)
```

---

## ⚡ Quick Start (5 Minutes)

### Prerequisites
- Google Cloud Console access with **Organization Admin** + **Billing Admin** roles
- All tools auto-install via `check_and_install.sh` (macOS, Linux, Windows WSL)

### Deploy

```bash
# 1. FIND YOUR IDs
#    • Organization ID: https://console.cloud.google.com → Select Org → URL
#    • Billing Account ID: https://console.cloud.google.com/billing

# 2. EDIT CONFIG
#    Open config.yaml and fill:
#      organization_id: "YOUR_ORG_ID"
#      billing_account: "YOUR_BILLING_ID"

# 3. INSTALL TOOLS
./check_and_install.sh

# 4. SETUP FOUNDATION
./bootstrap.sh

# 5. DEPLOY INFRASTRUCTURE
./run_all_phases.sh    # OR manually:
#   cd 0-Bootstrap && terraform init -backend-config=backend-config.hcl && terraform apply
#   cd 1-Resman && terraform init -backend-config=backend-config.hcl && terraform apply
#   cd 2-Networking && terraform init -backend-config=backend-config.hcl && terraform apply
#   cd 3-Projects && terraform init -backend-config=backend-config.hcl && terraform apply

# 6. VERIFY
gcloud projects list
gcloud compute networks list
```

**Total time: ~25 minutes**

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [START_HERE.md](START_HERE.md) | **READ THIS FIRST** - Layman's map, pre-flight checklist, troubleshooting |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Step-by-step hands-on deployment walkthrough |
| [config.yaml](config.yaml) | Master configuration file (edit here!) |
| Phase TF files | Each phase has inline comments explaining every line |

---

## 🏗️ Four-Phase Architecture

### Phase 0: Bootstrap
- 🔐 Creates Terraform service account
- 🔌 Enables required Google Cloud APIs
- 📦 Creates GCS bucket for remote state
- 💾 Sets up state locking

**Cost: $0 | Time: 3 min**

### Phase 1: Resource Manager
- 🗂️ Creates organization folder structure
- 📚 Creates spoke projects (greenfield or imports brownfield)
- 💳 Assigns billing accounts
- 🔑 Sets up IAM permissions

**Cost: $0 | Time: 5 min**

### Phase 2: Networking  
- 🌐 Creates Hub VPC (central)
- 🌐 Creates Spoke VPCs (one per project)
- 🔗 Enables VPC Peering (hub ↔ spokes)
- 🚨 Creates firewall rules
- 🔒 Enables Private Google Access

**Cost: ~$10-50/mo | Time: 10 min**

### Phase 3: Projects Configuration
- 📊 Enables Cloud Logging (audit logs → BigQuery)
- 💰 Creates budget alerts ($1/mo per spoke)
- 🛡️ Applies organization policies (security guardrails)
- 🔍 Enables Security Command Center (SCC) STANDARD (free)
- 🏷️ Applies FinOps labels & tags

**Cost: ~$5-20/mo | Time: 5 min**

---

## 💰 Cost Profiles

### "FREE" Profile
- 🖥️ Machine: `e2-micro` (first 730 hrs/month FREE on GCP)
- 🌍 Region: `us-central1` only (free tier region)
- 🔌 Network: Standard tier (cheaper data transfer)
- **Expected: $0-10/month**

### "PAID" Profile
- 🖥️ Machine: `e2-standard-2` (more powerful)
- 🌍 Region: Any region
- 🔌 Network: Premium tier (better performance, HA)
- 🔐 Security: Cloud Armor (DDoS protection)
- **Expected: $50-200+/month**

---

## 📊 What Gets Deployed

| Component | Quantity | Purpose |
|-----------|----------|---------|
| GCP Projects | 1 hub + N spokes | Billing/security isolation |
| VPCs | 1 hub + N spokes | Private networks |
| Subnets | 1 hub + N spokes | Logical divisions |
| VPC Peerings | N hub↔spoke | Network connectivity |
| Firewall Rules | 2N + hub | Traffic control |
| Service Accounts | 1 (terraform) + N | Application identity |
| Cloud NAT | Optional | Internet egress for private VMs |
| Org Policies | 3 (baseline) | Security enforcement |
| Budget Alerts | N | Cost control |
| BigQuery Dataset | 1 | Audit logs storage |

---

## 🔒 Security Features

✅ **Org Policies**
- Disable default networks (forces intentional design)
- Disable service account keys (prevents leaked credentials)
- Enforce uniform bucket access (blocks mixed ACLs)

✅ **Network Security**
- VPC isolation per project
- Private Google Access (no internet for API access)
- Firewall rules for east-west segmentation

✅ **Audit & Compliance**
- All admin actions logged → BigQuery
- Ready for SOC 2, PCI-DSS, HIPAA reporting
- Security Command Center scanning

✅ **Cost Control**
- Budget alerts per project ($1 default threshold)
- Auto-tagging for cost allocation
- Cost profile enforcement (free vs. paid)

---

## 🚀 Getting Started (3 Steps)

1. **Read [START_HERE.md](START_HERE.md)**  
   ~ 10 minutes to understand the structure
   
2. **Edit [config.yaml](config.yaml)**  
   ~ 2 minutes to fill in your Org ID & Billing ID
   
3. **Run [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**  
   ~ 25 minutes for full deployment

---

## 🧹 Cleanup

**Stop all costs immediately:**

```bash
./nuke.sh
# Type: yes, destroy everything
# It will:
#   1. Remove project liens
#   2. Delete all resources
#   3. Destroy all projects
#   4. Delete state bucket
```

⚠️ **This is irreversible.** All data will be permanently deleted.

---

## 📈 Scaling & Customization

### Add a New Spoke
1. Edit `config.yaml`:
   ```yaml
   spokes:
     - name: "my-new-spoke"
       type: "greenfield"
       cost_profile: "free"
   ```
2. Run phases 1-3 again:
   ```bash
   cd 1-Resman && terraform apply
   cd ../2-Networking && terraform apply
   cd ../3-Projects && terraform apply
   ```

### Import Existing Project
1. Edit `config.yaml`:
   ```yaml
   spokes:
     - name: "legacy-system"
       type: "brownfield"
       existing_project_id: "my-old-project-123"
   ```
2. Manually import into Terraform:
   ```bash
   cd 1-Resman
   terraform import google_project.spoke_brownfield[legacy-system] my-old-project-123
   terraform apply
   ```

### Enable Premium Features
1. Edit `config.yaml`:
   ```yaml
   cost_profile: "paid"  # Instead of "free"
    free_tier_modules:
       enable_scc_standard: true
       enable_iap_access: true
       enable_org_policies: true
    chargeable_modules:
       enable_central_logging: true
       enable_cloud_nat: true
   ```
2. Re-deploy: `./run_all_phases.sh`

---

## 🐛 Troubleshooting

| Error | Solution |
|-------|----------|
| `terraform not found` | Run `./check_and_install.sh` again, reopen VS Code |
| `Permission denied` | Verify you have Organization Admin + Billing Admin roles |
| `state locked` | Wait 5 min or delete lock: `gsutil rm gs://BUCKET/terraform/state/PHASE/.terraform.lock.hcl` |
| `API not enabled` | Wait 30s, run `terraform apply` again (APIs propagate slowly) |
| One phase fails | Re-run `terraform apply` in that phase (Terraform is idempotent) |

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for full troubleshooting.

---

## 📞 Support & References

| Resource | Link |
|----------|------|
| Google Cloud Documentation | https://cloud.google.com/docs |
| Terraform Google Provider | https://registry.terraform.io/providers/hashicorp/google/latest/docs |
| VPC Peering | https://cloud.google.com/vpc/docs/vpc-peering |
| Hub-and-Spoke Architecture | https://cloud.google.com/architecture/hubandspoke |
| Cloud Fabric FAST | https://github.com/GoogleCloudPlatform/cloud-foundation-fabric |

---

## 📜 License & Attribution

This landing zone is based on [Google Cloud Platform's Cloud Foundation Fabric FAST templates](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric), adapted for ease of use by teams with limited GCP experience.

**Attribution:** Built with ❤️ for enterprise Google Cloud deployments.

---

## ✨ What's Included

✅ Production-ready Terraform v1.5+  
✅ Multi-OS support (macOS, Linux, Windows WSL)  
✅ Auto-detection and remediation (handles missing tools)  
✅ Security baseline (org policies, SCC, audit logging)  
✅ FinOps integration (budgets, tags, cost profiles)  
✅ Comprehensive documentation (no Terraform experience required)  
✅ One-command cleanup (`nuke.sh`)  

---

## 🎉 Ready to Deploy?

**Next Step:** Open [START_HERE.md](START_HERE.md) and follow the pre-flight checklist.

**Questions?** Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed troubleshooting.

**Ready to clean up?** Run `./nuke.sh` to delete everything.

---

**Happy GCP Deploying! 🚀**
