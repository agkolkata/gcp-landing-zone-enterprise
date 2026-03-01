# 📖 Deployment Guide - Step-by-Step Reference

This guide provides detailed, hands-on instructions for deploying your GCP Landing Zone. Follow it line-by-line.

---

## 🎯 Quick Start (5 Steps)

If you're in a hurry, this is all you need:

```bash
# 1. Prepare config
# Edit config.yaml and fill in YOUR_ORG_ID and YOUR_BILLING_ID

# 2. Check tools
./check_and_install.sh

# 3. Bootstrap
./bootstrap.sh

# 4. Deploy all phases
./run_all_phases.sh

# 5. Verify
gcloud projects list
```

**Done!** Infrastructure is live.

---

## 📋 Detailed Deployment (Step-by-Step)

### Step 1: Find Your Organization & Billing IDs

#### Find Organization ID:
1. Open https://console.cloud.google.com in browser
2. Top-left corner: Click the **project/org selector** (the folder icon)
3. A popup appears. Click **ALL** at the top right
4. Find your organization in the list
5. Click on it
6. The URL changes to: `https://console.cloud.google.com/home/dashboard?organizationId=**123456789**`
7. Copy the number (e.g., `123456789`)

#### Find Billing Account ID:
1. In same console, go to **☰ Menu** → **Billing**
2. Click **My billing accounts**
3. Find the billing account you want to use
4. Click on it
5. The URL shows: `https://console.cloud.google.com/billing/0092F0-12AB34-56CD78`
6. Copy that code (e.g., `0092F0-12AB34-56CD78`)

**Important:** Make sure you have these IAM roles:
- ✅ Organization Administrator
- ✅ Billing Account Administrator

If you don't, ask your GCP admin to grant them.

---

### Step 2: Edit config.yaml

```bash
# Open the file in VS Code:
# File → Open → config.yaml

# Find these lines and replace:
organization_id: "YOUR_ORG_ID"    ← Replace with your Org ID
billing_account: "YOUR_BILLING_ID" ← Replace with your Billing ID

# For example:
organization_id: "123456789"
billing_account: "0092F0-12AB34-56CD78"

# Save the file (Ctrl+S)
```

✅ **Checkpoint:** Open the file and verify the numbers are correct.

---

### Step 3: Check & Install Tools

Open **VS Code Terminal** (Ctrl+` or View → Terminal):

```bash
./check_and_install.sh
```

**What this does:**
- ✓ Checks if `gcloud` is installed
- ✓ Checks if `terraform` is installed
- ✓ Checks if `git` is installed
- ✓ **Installs them if missing**

**If script installs something:**
- Close VS Code completely
- Reopen VS Code
- Run the script again to confirm everything is installed

**Expected output:**
```
✓ gcloud is installed: Google Cloud SDK 123.0.0
✓ Terraform is installed: Terraform v1.5.0
✓ Git is installed: git version 2.40.0
✓ All dependencies are ready!
```

---

### Step 4: Bootstrap (Setup Foundation)

Still in **VS Code Terminal**:

```bash
./bootstrap.sh
```

**What this does:**
1. Logs you into Google Cloud (opens browser)
2. Enables required APIs (takes 5 minutes with intentional delays)
3. Creates a GCS bucket for Terraform backups
4. Creates backend-config.hcl files for each phase

**You'll see:**
```
[STEP 1/5] Authenticating to Google Cloud...
Opening browser for Google Cloud authentication...
```

A browser window opens. Sign in with your Google account.

**Then you'll see API enablements** with 30-second waits:
```
Enabling Resource Manager API... ✓
  → Waiting 30s for API propagation...
Enabling Billing API... ✓
  → Waiting 30s for API propagation...
```

**This is NORMAL.** The delays prevent "race conditions" (race conditions = APIs interfering with each other).

⏳ **Wait** for the script to finish (about 5 minutes).

**Final output:**
```
✓ Bootstrap complete!
  • Remote state bucket: gs://lz-automation-12345-tf-state
  • Versioning + Locking enabled
  • Public access blocked
Next steps:
  1. cd 0-Bootstrap
  2. terraform init -backend-config=backend-config.hcl
  3. terraform apply
```

---

### Step 5: Deploy Phase 0 (Bootstrap)

This phase creates the Terraform service account and permissions.

```bash
# Navigate to phase 0
cd 0-Bootstrap

# Initialize Terraform (point it to the state bucket)
terraform init -backend-config=backend-config.hcl -upgrade

# Show what will be created (preview)
terraform plan

# Create it!
terraform apply
```

When you run `terraform apply`, you'll see:

```
google_project_service.required_apis[compute.googleapis.com]: Creating...
google_project_service.required_apis[logging.googleapis.com]: Creating...
google_service_account.terraform: Creating...

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
terraform_service_account_email = "terraform-lz@..."
landing_zone_folder_id = "123456789"
```

**Type `yes` when Terraform asks for confirmation.**

✅ **Phase 0 complete!**

---

### Step 6: Deploy Phase 1 (Resman - Resource Manager)

This phase creates your spoke projects.

```bash
# Go back to root directory
cd ..

# Navigate to phase 1
cd 1-Resman

# Initialize (same as before)
terraform init -backend-config=backend-config.hcl -upgrade

# Preview
terraform plan

# Create projects!
terraform apply
```

**You'll see:**
```
google_project.spoke_greenfield["sandbox"]: Creating...
google_project.spoke_greenfield["production"]: Creating...
google_project.spoke_greenfield["data-analytics"]: Creating...

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:
spoke_projects = {
  "data-analytics" = {
    "project_id" = "lz-data-analytics-a1b2c3"
    ...
  }
  ...
}
```

✅ **Phase 1 complete!** Projects are created.

---

### Step 7: Deploy Phase 2 (Networking)

This phase creates VPC networks and connects them (hub-and-spoke).

```bash
cd ..
cd 2-Networking

terraform init -backend-config=backend-config.hcl -upgrade
terraform plan
terraform apply
```

**You'll see:**
```
google_compute_network.hub: Creating...
google_compute_network.spokes["sandbox"]: Creating...
google_compute_network.spokes["production"]: Creating...
google_compute_network_peering.hub_to_spokes["sandbox"]: Creating...

Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
hub_network = {
  "cidr" = "10.0.0.0/20"
  "id" = "projects/.../global/networks/hub-vpc"
  "name" = "hub-vpc"
}
spoke_networks = {
  "sandbox" = {
    "id" = "projects/.../global/networks/sandbox-vpc"
    ...
  }
  ...
}
```

✅ **Phase 2 complete!** Networks are connected.

---

### Step 8: Deploy Phase 3 (Projects - Security & Logging)

This final phase sets up security, logging, budgets, and compliance.

```bash
cd ..
cd 3-Projects

terraform init -backend-config=backend-config.hcl -upgrade
terraform plan
terraform apply
```

**You'll see:**
```
google_billing_budget.spoke_budgets["sandbox"]: Creating...
google_logging_project_sink.spoke_to_central["sandbox"]: Creating...
google_organization_policy.skip_default_network[0]: Creating...

Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:
audit_logs_dataset = "audit_logs"
budget_alerts_created = 3
org_policies_applied = {
  "disable_sa_keys" = "iam.disableServiceAccountKeyCreation"
  "skip_default_network" = "compute.skipDefaultNetworkCreation"
  "uniform_buckets" = "storage.uniformBucketLevelAccess"
}
security_command_center = "✓ Enabled (STANDARD tier - free)"
```

✅ **Phase 3 complete!** Infrastructure fully configured.

---

## ✅ Verification Checklist

After all phases complete, verify:

```bash
# 1. Check all projects exist
gcloud projects list
# Should show: sandbox-project, production-project, data-analytics-project

# 2. Check networks exist
gcloud compute networks list
# Should show: hub-vpc, sandbox-vpc, production-vpc, data-analytics-vpc

# 3. Check peerings
gcloud compute networks peerings list --network=hub-vpc
# Should show: hub-to-sandbox, hub-to-production, hub-to-data-analytics

# 4. Check firewall rules
gcloud compute firewall-rules list | grep landing-zone
# Should show rules for hub and each spoke

# 5. Check budget alerts
gcloud billing budgets list --billing-account=YOUR_BILLING_ID
# Should show 3 budgets (one per spoke)

# 6. Check audit logs
bq ls --dataset_id audit_logs
# Should show audit_logs dataset
```

---

## 🚨 Troubleshooting

### "terraform not found"
```bash
# Reinstall terraform:
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install terraform

# Then close & reopen VS Code
```

### "Permission denied" during bootstrap
- Make sure you have `Organization Administrator` role
- Ask your GCP admin to grant it
- Verify at: Cloud Console → Settings → Organization settings → IAM

### "state locked" error
```bash
# Someone else is running Terraform. Wait 5-10 minutes or:
# Delete lock in bucket:
gsutil rm gs://YOUR_STATE_BUCKET/terraform/state/PHASE/.terraform.lock.hcl
```

### "API not enabled" error
```bash
# Enable it manually:
gcloud services enable compute.googleapis.com
# Wait 30 seconds, then retry terraform apply
```

### "quota exceeded" error
- You've hit the project creation limit
- Go to Cloud Console → IAM → Quotas
- Click the quota and request increase

### One phase fails mid-way
```bash
# Just run terraform apply again in that phase
cd FAILED_PHASE
terraform apply
# Terraform is idempotent - it will pick up where it left off
```

---

## 📞 Support Resources

| Issue | Where to Find Help |
|-------|-------------------|
| GCP Concepts | https://cloud.google.com/docs |
| Terraform Syntax | https://registry.terraform.io/providers/hashicorp/google/latest/docs |
| VPC Peering | https://cloud.google.com/vpc/docs/vpc-peering |
| Org Policies | https://cloud.google.com/resource-manager/docs/organization-policy/overview |
| Cloud Logging | https://cloud.google.com/logging/docs |

---

## 🧹 Cleanup (Delete Everything)

If you want to **DELETE all infrastructure and stop all charges**:

```bash
./nuke.sh
# Type: yes, destroy everything
# Wait for cleanup to complete
```

⚠️ **This cannot be undone!** All data will be lost.

---

##Done! 🎉

Your GCP Landing Zone is now ready for deployment!

**Next steps:**
1. Deploy your first application
2. Monitor costs in Cloud Console → Billing
3. Review audit logs in BigQuery
4. Set up alerts for budget warnings

See **START_HERE.md** for additional reference docs.
