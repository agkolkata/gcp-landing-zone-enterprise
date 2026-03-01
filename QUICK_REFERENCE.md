# ⚡ Quick Reference Card (Print This!)

**GCP Hub-and-Spoke Landing Zone - One Page Cheat Sheet**

---

## 🎯 Pre-Deployment (Do This First!)

### 1. Find Your IDs
```
Organization ID:   https://console.cloud.google.com
  → Top-left selector → ALL → Your Org
  → Copy the number from URL: ?organizationId=123456789

Billing Account ID: https://console.cloud.google.com/billing
  → My billing accounts → Your account
  → Copy ID from URL: accountId=000000-000000-000000
```

### 2. Check IAM Roles (ask admin if needed)
- ✅ Organization Administrator
- ✅ Billing Account Administrator

### 3. Edit config.yaml
```bash
organization_id: "123456789"        ← Your Org ID
billing_account: "000000-000000"    ← Your Billing ID
```

---

## 🚀 Deployment (Copy & Paste)

### Option A: Automatic (Easiest)
```bash
./check_and_install.sh      # Install tools if needed
./bootstrap.sh              # Setup foundation (5 min)
./run_all_phases.sh         # Deploy everything (25 min)
```

### Option B: Manual (If run_all_phases.sh fails)
```bash
# Phase 0
cd 0-Bootstrap
terraform init -backend-config=backend-config.hcl
terraform apply
cd ..

# Phase 1
cd 1-Resman
terraform init -backend-config=backend-config.hcl
terraform apply
cd ..

# Phase 2
cd 2-Networking
terraform init -backend-config=backend-config.hcl
terraform apply
cd ..

# Phase 3
cd 3-Projects
terraform init -backend-config=backend-config.hcl
terraform apply
cd ..
```

---

## ✅ Verification

```bash
# Check projects
gcloud projects list

# Check networks
gcloud compute networks list

# Check firewalls
gcloud compute firewall-rules list | head -20

# Check budgets
gcloud billing budgets list --billing-account=YOUR_BILLING_ID

# Check logs dataset
bq ls --dataset_id audit_logs
```

---

## 🧹 Cleanup (Delete Everything)

```bash
./nuke.sh
# Type: yes, destroy everything
# ⚠️ This cannot be undone!
```

---

## 🐛 Common Errors & Fixes

| Error | Fix |
|-------|-----|
| `terraform not found` | Run `./check_and_install.sh` again, reopen VS Code |
| `Permission denied` | Verify Organization Admin + Billing Admin roles |
| `state locked` | Wait 5 min or: `gsutil rm gs://BUCKET/terraform/state/PHASE/.terraform.lock.hcl` |
| `API not enabled` | Wait 30s, run `terraform apply` again |
| `project quota exceeded` | Go to IAM → Quotas, request increase |

---

## 📁 4 Phases Explained

| Phase | What | Time | Cost |
|-------|------|------|------|
| **0** | Service account, APIs, state bucket | 3 min | $0 |
| **1** | Create/import projects | 5 min | $0 |
| **2** | Hub-and-Spoke networks, peering | 10 min | ~$10-50/mo |
| **3** | Logging, budgets, security | 5 min | ~$5-20/mo |

---

## 💰 Cost Profiles

### "FREE" (Newbies)
- Region: us-central1 only
- VM: e2-micro (free tier)
- Network: Standard tier
- **Cost: $0-10/month**

### "PAID" (Production)
- Any region
- VM: e2-standard-2+
- Network: Premium + HA VPN + Cloud Armor
- **Cost: $50-200+/month**

---

## 🔑 Key Facts

- ✅ Hub-and-Spoke VPCs (hub talks to all spokes)
- ✅ Multi-project (separate billing per project)
- ✅ Greenfield (create new) or Brownfield (import existing)
- ✅ Audit logs → BigQuery (SOC2/PCI-DSS ready)
- ✅ Org Policies (security guardrails)
- ✅ Budget alerts ($1/month default)
- ✅ Private Google Access (VMs don't need public IPs)

---

## 📖 Where to Find Help

| Need | See |
|------|-----|
| Getting started | START_HERE.md |
| Step-by-step | DEPLOYMENT_GUIDE.md |
| All files | MANIFEST.md |
| Overview | README.md |

---

## ⚠️ Important Notes

1. **Edit config.yaml FIRST** before running anything
2. **bootstrap.sh needs 5 minutes** with intentional delays (don't interrupt!)
3. **terraform apply needs 'yes' confirmation** after terraform plan
4. **Scripts are idempotent** - safe to re-run if something fails
5. **Remote state is locked** - only one person deploys at a time
6. **nuke.sh is irreversible** - deletes EVERYTHING

---

## 🎯 Typical Timeline

```
0:00  - Edit config.yaml
0:05  - Run check_and_install.sh
0:10  - Run bootstrap.sh
0:15  - Start run_all_phases.sh
0:20  - Phase 0 complete
0:30  - Phase 1 complete
0:45  - Phase 2 complete
1:00  - Phase 3 complete
1:05  - Verify all projects/networks created
```

**Total: ~65 minutes (first time)**

---

## 🔐 Security Defaults

Automatically configured:
- ✅ Org Policies enabled
- ✅ Audit logging to BigQuery
- ✅ SCC STANDARD (free scanning)
- ✅ Private Google Access
- ✅ Firewall rules per network
- ✅ Service accounts per project
- ✅ IAM permissions scoped

---

## 🚨 Emergency Stop

**Need to stop everything NOW:**

```bash
# Option 1: Stop the script
Ctrl+C          # In terminal (graceful)

# Option 2: Delete projects manually
gcloud projects delete PROJECT_ID --quiet

# Option 3: Nuclear option (delete everything)
./nuke.sh
```

---

## ✨ Pro Tips

- 💡 Save output of each phase: `terraform apply 2>&1 | tee phase-X-output.log`
- 💡 Check state: `terraform state show`
- 💡 Use `-parallelism=1` if you hit API rate limits
- 💡 Monitor costs: https://console.cloud.google.com/billing
- 💡 Audit logs: `bq query --nouse_legacy_sql "SELECT * FROM \`ORG_ID.audit_logs.cloudaudit_googleapis_com_activity\` LIMIT 10"`

---

## 📞 Need Help?

1. Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review inline comments in .tf files
3. Check [MANIFEST.md](MANIFEST.md) for file reference
4. Google: "GCP [error message]"
5. GCP docs: https://cloud.google.com/docs

---

**Print this page. Tape it to your monitor. You're ready to deploy! 🚀**

Last updated: March 1, 2026
