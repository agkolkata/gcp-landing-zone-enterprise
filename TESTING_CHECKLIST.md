# GCP Landing Zone - Real-World Testing Checklist
**Date:** March 1, 2026  
**Purpose:** Step-by-step guide for testing in actual Google Cloud environment

---

## Prerequisites Validation (Before Any Deployment)

### 1. GCP Organization Access ✅
```bash
# Verify you have org access
gcloud organizations list

# Expected: Should show your organization ID
# If empty: You need Organization Admin access
```

**What to verify:**
- [ ] Organization ID matches your `config.yaml`
- [ ] You can list the organization
- [ ] Organization is active

### 2. IAM Permissions Check ✅
```bash
# Check your current account
gcloud auth list

# Get your user email
USER_EMAIL=$(gcloud config get-value account)
echo "Testing with: $USER_EMAIL"

# Check org-level IAM
gcloud organizations get-iam-policy YOUR_ORG_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$USER_EMAIL"
```

**Required roles:**
- [ ] `roles/resourcemanager.organizationAdmin`
- [ ] `roles/resourcemanager.folderAdmin`
- [ ] `roles/billing.admin`
- [ ] `roles/iam.securityAdmin`
- [ ] `roles/serviceusage.serviceUsageAdmin`

**If missing:** Contact your org admin to grant these roles.

### 3. Billing Account Access ✅
```bash
# List billing accounts
gcloud billing accounts list

# Check if you can link projects
gcloud billing accounts get-iam-policy YOUR_BILLING_ACCOUNT_ID
```

**What to verify:**
- [ ] Billing account ID matches `config.yaml`
- [ ] Billing account is ACTIVE (not closed)
- [ ] You have `roles/billing.admin` on the account
- [ ] Credit card or payment method is attached

### 4. Quota Check ✅
```bash
# Check project quota (you need capacity for at least 3 projects)
gcloud compute project-info describe --project=YOUR_ORG_ID \
  --format="value(quotas)"
```

**What to verify:**
- [ ] Can create at least 3 new projects
- [ ] Org has capacity for folders
- [ ] No quota restrictions on Compute Engine

---

## Phase 0: Pre-Deployment Testing

### 1. Config Validation ✅
```bash
# In VS Code terminal
cd C:/Users/User/Downloads/GCP-LANDING-ZONE-ENT-1

# Update config.yaml with REAL values
# Replace:
#   - YOUR_ORG_ID → actual org ID (e.g., 123456789012)
#   - YOUR_BILLING_ID → actual billing account (e.g., 01ABCD-ABCDEF-ABCDEF)
#   - Optionally change default_region

# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('config.yaml'))" && echo "✓ Valid YAML"
```

**Critical checks:**
- [ ] `organization_id` is numeric and real
- [ ] `billing_account` format: `XXXXXX-XXXXXX-XXXXXX`
- [ ] `default_region` is valid (e.g., `us-central1`, `us-east1`)
- [ ] No placeholder values remain (`YOUR_ORG_ID`, `YOUR_BILLING_ID`)

### 2. Tool Installation ✅
```bash
# Run the installer
./check_and_install.sh
```

**What to verify:**
- [ ] gcloud SDK installed and in PATH
- [ ] Terraform 1.5+ installed
- [ ] tfsec installed (for security scanning)
- [ ] Git installed
- [ ] All tools pass version checks

### 3. Authentication ✅
```bash
# Login with your user account
gcloud auth login

# Set application-default credentials (for Terraform)
gcloud auth application-default login

# Verify authentication
gcloud auth list
# Should show ACTIVE account with asterisk (*)
```

**What to verify:**
- [ ] Logged in with correct account
- [ ] Application-default credentials set
- [ ] Can run `gcloud projects list` without errors

---

## Phase 1: Bootstrap Testing (Org-Level Setup)

### 1. Dry-Run Bootstrap ✅
```bash
# Run bootstrap script (creates locals.tf, backend-config)
./bootstrap.sh
```

**What to verify:**
- [ ] Script completes without errors
- [ ] `0-Bootstrap/locals.tf` created with your org ID
- [ ] `0-Bootstrap/backend-config.hcl` created with bucket name
- [ ] All 4 phase directories get `locals.tf` + `backend-config.hcl`
- [ ] No "permission denied" errors

**Expected output:**
```
✓ Config validated
✓ Generated locals.tf for all phases
✓ Generated backend-config.hcl
✓ Enabled required APIs (may take 2-3 minutes)
```

### 2. Security Scan ✅
```bash
# Scan before deployment
./plan_and_scan.sh
```

**What to verify:**
- [ ] tfsec runs successfully (may show warnings, that's OK)
- [ ] Terraform plans show resource counts for each phase
- [ ] No "credential" or "authentication" errors
- [ ] Plan output shows your org ID in resource names

**Expected plan summary:**
```
0-Bootstrap: ~8-12 resources to add
1-Resman: ~3-6 resources to add (depends on spoke count)
2-Networking: ~15-25 resources to add
3-Projects: ~6-12 resources to add
```

### 3. Deploy Bootstrap Phase ✅
```bash
cd 0-Bootstrap
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply
```

**What to verify:**
- [ ] `terraform init` downloads google provider successfully
- [ ] State bucket gets created: `YOUR_ORG_ID-terraform-state`
- [ ] Service account created: `terraform-sa@...`
- [ ] Landing zone folder created under org root
- [ ] All base APIs enabled (check Cloud Console → APIs & Services)

**Expected resources created:**
- 1 GCS bucket (state storage)
- 1 Service account (Terraform automation)
- 1 Folder (landing zone root)
- ~15 API services enabled
- IAM bindings for service account

**Verification commands:**
```bash
# Check state bucket
gsutil ls -b gs://YOUR_ORG_ID-terraform-state

# Check service account
gcloud iam service-accounts list --project=YOUR_ORG_ID

# Check folder
gcloud resource-manager folders list --organization=YOUR_ORG_ID

# Check enabled APIs
gcloud services list --enabled --project=YOUR_ORG_ID | grep -E "(compute|storage|iam)"
```

---

## Phase 2: Resource Manager Testing (Projects)

### 1. Deploy Resman Phase ✅
```bash
cd ../1-Resman
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply
```

**What to verify:**
- [ ] Remote state from Bootstrap loaded (check `terraform show`)
- [ ] Projects created for each spoke in config.yaml
- [ ] Billing linked to all projects
- [ ] Projects placed in landing zone folder

**Expected resources:**
- 2-3 GCP projects (sandbox, enterprise-workloads, etc.)
- Billing linkage for each project
- Project-level IAM bindings
- Service account access to projects

**Verification commands:**
```bash
# List all projects
gcloud projects list --filter="parent.id=FOLDER_ID_FROM_BOOTSTRAP"

# Check billing linkage
gcloud billing projects describe PROJECT_ID

# Verify project is in correct folder
gcloud projects describe PROJECT_ID --format="value(parent.id)"
```

### 2. Test Brownfield Reference (Optional) ✅

**If you have a legacy network to test:**

1. Update `config.yaml`:
```yaml
spokes:
  - name: "legacy-db-network"
    type: "brownfield_reference"
    existing_network_id: "projects/YOUR-OLD-PROJECT/global/networks/YOUR-NETWORK"
```

2. Re-apply Resman:
```bash
terraform plan
terraform apply
```

**What to verify:**
- [ ] No error when referencing existing network
- [ ] Resman output includes `brownfield_reference_network_ids`

---

## Phase 3: Networking Testing (VPCs, Peering, IPAM)

### 1. Deploy Networking Phase ✅
```bash
cd ../2-Networking
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply
```

**What to verify:**
- [ ] Hub VPC created in org project
- [ ] Spoke VPCs created (one per spoke project)
- [ ] VPC peering established (hub ↔ spokes)
- [ ] Subnets created with IPAM-calculated CIDRs
- [ ] Firewall rules created (IAP, internal, etc.)

**Expected resources:**
- 1 Hub VPC (in org/bootstrap project)
- 2-3 Spoke VPCs (in spoke projects)
- 4-6 VPC peering connections
- 2-3 Subnets per VPC
- 3-5 Firewall rules per VPC

**Verification commands:**
```bash
# List all VPCs
gcloud compute networks list --project=YOUR_ORG_ID
gcloud compute networks list --project=SPOKE_PROJECT_1
gcloud compute networks list --project=SPOKE_PROJECT_2

# Check peering status
gcloud compute networks peerings list --network=hub-vpc --project=YOUR_ORG_ID

# Verify IPAM allocation (no overlaps)
terraform output spoke_primary_cidrs
terraform output spoke_pod_cidrs
terraform output spoke_service_cidrs

# Check firewall rules
gcloud compute firewall-rules list --project=SPOKE_PROJECT_1
```

**IPAM validation:**
- [ ] All CIDRs are unique (no overlaps)
- [ ] CIDRs carved from hub CIDR (`10.0.0.0/20` by default)
- [ ] Pod/service ranges present if GKE enabled

### 2. Test Peering Connectivity ✅

**Create test VMs:**
```bash
# In hub VPC
gcloud compute instances create test-hub \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --subnet=hub-subnet \
  --project=YOUR_ORG_ID

# In spoke project
gcloud compute instances create test-spoke \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --subnet=sandbox-subnet \
  --project=SPOKE_PROJECT_1

# Test connectivity (from hub to spoke)
gcloud compute ssh test-hub --zone=us-central1-a --project=YOUR_ORG_ID
# Inside VM:
ping -c 4 SPOKE_VM_INTERNAL_IP
```

**What to verify:**
- [ ] Ping successful (proves peering works)
- [ ] No "destination unreachable" errors
- [ ] Round-trip time < 10ms (internal network)

**Cleanup test VMs:**
```bash
gcloud compute instances delete test-hub --zone=us-central1-a --project=YOUR_ORG_ID --quiet
gcloud compute instances delete test-spoke --zone=us-central1-a --project=SPOKE_PROJECT_1 --quiet
```

### 3. Test Workload Foundations (Optional) ✅

**If `enable_gcve_networking: true`:**
```bash
# Check GCVE PSA allocation
terraform output spoke_gcve_cidrs

# Verify service networking connection
gcloud services vpc-peerings list --service=servicenetworking.googleapis.com --project=SPOKE_PROJECT
```

**If `enable_gke_multi_cloud: true`:**
```bash
# Verify secondary ranges exist
gcloud compute networks subnets describe SUBNET_NAME \
  --region=us-central1 \
  --project=SPOKE_PROJECT \
  --format="value(secondaryIpRanges)"

# Check GKE Hub API enabled
gcloud services list --enabled --project=SPOKE_PROJECT | grep gkehub
```

---

## Phase 4: Governance Testing (Budgets, SCC)

### 1. Deploy Projects Phase ✅
```bash
cd ../3-Projects
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply
```

**What to verify:**
- [ ] Budget alerts created for each project
- [ ] Budget threshold set to $1 USD (or your config value)
- [ ] Security Command Center API enabled (if `enable_scc_standard: true`)

**Expected resources:**
- 2-3 Budget alerts (one per spoke)
- 2-3 SCC API enablements
- Notification channel for email alerts (if configured)

**Verification commands:**
```bash
# List budgets
gcloud billing budgets list --billing-account=YOUR_BILLING_ACCOUNT_ID

# Check SCC API
gcloud services list --enabled --project=SPOKE_PROJECT | grep securitycenter

# View budget details
gcloud billing budgets describe BUDGET_ID --billing-account=YOUR_BILLING_ACCOUNT_ID
```

---

## Post-Deployment Validation

### 1. State Integrity Check ✅
```bash
# Verify remote state for each phase
cd 0-Bootstrap && terraform show && cd ..
cd 1-Resman && terraform show && cd ..
cd 2-Networking && terraform show && cd ..
cd 3-Projects && terraform show && cd ..
```

**What to verify:**
- [ ] Each phase shows resources in state
- [ ] No "state locked" errors
- [ ] State bucket contains 4 state files

**Check state bucket:**
```bash
gsutil ls -r gs://YOUR_ORG_ID-terraform-state/
```

Expected structure:
```
terraform/state/0-Bootstrap/default.tfstate
terraform/state/1-Resman/default.tfstate
terraform/state/2-Networking/default.tfstate
terraform/state/3-Projects/default.tfstate
```

### 2. Cost Mode Testing ✅

**Test `strict_free` enforcement:**

1. In `config.yaml`, set a spoke to `strict_free`:
```yaml
spokes:
  - name: "free-tier-test"
    type: "greenfield"
    cost_mode: "strict_free"
```

2. Re-apply networking:
```bash
cd 2-Networking
terraform plan
```

**What to verify:**
- [ ] Plan shows Cloud NAT disabled for `strict_free` spoke
- [ ] Centralized ingress disabled
- [ ] GCVE/GKE features disabled even if YAML says true
- [ ] Check output: `auto_corrected_features`

### 3. Transparency Outputs ✅
```bash
# Check what was auto-corrected
cd 2-Networking
terraform output auto_corrected_features

# Check default injections
terraform output default_injected_values
```

**What to verify:**
- [ ] Output lists features that were disabled by `strict_free`
- [ ] Output lists defaults that were injected

---

## Cost Monitoring (Critical!)

### 1. Real-Time Cost Check ✅
```bash
# Check current charges
gcloud billing accounts describe YOUR_BILLING_ACCOUNT_ID \
  --format="value(displayName)"

# View billing dashboard
echo "Open: https://console.cloud.google.com/billing/YOUR_BILLING_ACCOUNT_ID"
```

**What to verify:**
- [ ] No unexpected charges (should be <$5 for basic testing)
- [ ] Budget alerts visible in console
- [ ] No runaway resources (check Compute Engine, Cloud Storage)

**Expected costs for minimal testing:**
- GCS state bucket: ~$0.026/month (standard storage)
- VPC networks: $0 (no charge for VPCs)
- Subnets: $0 (no charge)
- Peering: $0 (no charge)
- Budgets: $0 (free)
- IAP: $0 (free tier)

**Chargeable resources (if enabled):**
- Cloud NAT: ~$0.045/hour (~$32.40/month)
- Load balancers: ~$18/month minimum
- VMs (if created for testing): ~$4.28/month (e2-micro)

### 2. Set Billing Alerts ✅
```bash
# Verify budget was created
gcloud billing budgets list --billing-account=YOUR_BILLING_ACCOUNT_ID

# Check alert threshold
gcloud billing budgets describe BUDGET_ID \
  --billing-account=YOUR_BILLING_ACCOUNT_ID \
  --format="value(thresholdRules)"
```

**What to verify:**
- [ ] Budget alert triggers at 50% and 100%
- [ ] Email notifications configured (if you added alert_email)

---

## Teardown Testing (Critical - Cost Stop!)

### 1. Full Cleanup Test ✅
```bash
# Stop all charges immediately
./nuke.sh
# Type: yes, destroy everything
```

**What to verify during nuke:**
- [ ] Confirmation prompt appears
- [ ] Script removes project liens
- [ ] Terraform destroys all 4 phases (reverse order)
- [ ] All projects deleted
- [ ] State bucket deleted
- [ ] No errors about "resource in use"

**Expected duration:** 15-30 minutes for complete teardown

### 2. Post-Nuke Verification ✅
```bash
# Check no projects remain
gcloud projects list --filter="parent.id=FOLDER_ID"
# Should be empty

# Check folder is empty
gcloud resource-manager folders list --organization=YOUR_ORG_ID
# Should only show the landing zone folder (empty)

# Check state bucket is gone
gsutil ls -b gs://YOUR_ORG_ID-terraform-state
# Should return "not found"

# Verify billing
gcloud billing accounts get-charges YOUR_BILLING_ACCOUNT_ID
# Check for any remaining active resources
```

### 3. Orphan Resource Check ✅
```bash
# Check for zombie VMs
gcloud compute instances list --project=YOUR_ORG_ID
# Should be empty

# Check for orphaned disks
gcloud compute disks list --project=YOUR_ORG_ID
# Should be empty

# Check for orphaned IPs
gcloud compute addresses list --project=YOUR_ORG_ID
# Should be empty
```

---

## Selective Testing Scenarios

### Scenario 1: Minimal Free-Tier Test ✅
**Goal:** Test with zero recurring costs

**Config:**
```yaml
spokes:
  - name: "free-test"
    type: "greenfield"
    cost_mode: "strict_free"

global_modules:
  enable_cloud_nat: false
  enable_hybrid_connectivity: false

advanced_modules:
  enable_centralized_ingress: false
```

**Deploy:** Phases 0-3  
**Expected cost:** <$1/month (state bucket only)  
**Duration:** 1 hour  
**Teardown:** Run `nuke.sh` immediately after validation

---

### Scenario 2: Brownfield Import Test ✅
**Goal:** Test importing existing project

**Prerequisites:**
- Have an existing GCP project outside this landing zone
- Note the project ID

**Config update:**
```yaml
spokes:
  - name: "imported-legacy"
    type: "brownfield_adopt"
    existing_project_id: "your-existing-project"
```

**Steps:**
1. Deploy Phase 0-1 only
2. Check Terraform plan shows `import {}` block
3. Apply Phase 1 (Resman)
4. Verify project now shows in Terraform state
5. Teardown

---

### Scenario 3: Multi-Region Test ✅
**Goal:** Test region flexibility

**Config:**
```yaml
default_region: "us-east1"  # Change from us-central1
```

**Deploy:** Phases 0-3  
**Verification:**
```bash
# Check all resources created in us-east1
gcloud compute networks subnets list --filter="region:us-east1"
```

---

### Scenario 4: Production Simulation ✅
**Goal:** Full feature test (WARNING: $20-40/month cost)

**Config:**
```yaml
spokes:
  - name: "prod-simulation"
    cost_mode: "custom_mix"
    workload_foundations:
      enable_gcve_networking: true
      enable_gke_multi_cloud: true

global_modules:
  enable_cloud_nat: true

advanced_modules:
  enable_centralized_ingress: true
```

**Duration:** Deploy for 1-2 hours only, then teardown  
**Expected cost:** ~$2-4 for 2-hour test  
**Teardown:** Run `nuke.sh` immediately

---

## Testing Completion Checklist

### Pre-Deployment ✅
- [ ] Updated `config.yaml` with real values
- [ ] Verified IAM permissions
- [ ] Confirmed billing account active
- [ ] Installed all required tools
- [ ] Authenticated with gcloud

### Deployment Testing ✅
- [ ] Bootstrap phase deployed successfully
- [ ] Resman phase created projects
- [ ] Networking phase established peering
- [ ] Projects phase created budgets
- [ ] All Terraform validates pass
- [ ] All remote state files exist

### Feature Validation ✅
- [ ] IPAM allocations verified (no overlaps)
- [ ] VPC peering tested (ping successful)
- [ ] Cost mode enforcement verified (`strict_free` disables features)
- [ ] Budget alerts visible in console
- [ ] Transparency outputs show auto-corrections

### Cost Control ✅
- [ ] Current charges < $5 during testing
- [ ] Budget alerts configured
- [ ] No unexpected Compute Engine VMs
- [ ] No unexpected load balancers
- [ ] Teardown tested and successful

### Cleanup Verification ✅
- [ ] All projects deleted
- [ ] State bucket removed
- [ ] No orphaned resources
- [ ] Billing shows zero active resources
- [ ] Folder empty or removed

---

## Recommended Testing Timeline

**1-Hour Quick Test:**
- Deploy phases 0-3 with `strict_free` config
- Verify basic functionality
- Run `nuke.sh`
- **Cost:** <$1

**Half-Day Full Test:**
- Deploy with `custom_mix` and workload foundations
- Test peering connectivity
- Test brownfield scenarios
- Verify budget alerts
- Run `nuke.sh`
- **Cost:** $2-5

**Production Dress Rehearsal:**
- Deploy full environment
- Leave running 24 hours
- Monitor costs and alerts
- Test application deployment
- Run controlled teardown
- **Cost:** $20-40

---

## Troubleshooting Common Issues

### Issue: "Permission Denied" on gcloud commands
**Fix:**
```bash
gcloud auth login
gcloud config set project YOUR_ORG_ID
```

### Issue: Terraform state locked
**Fix:**
```bash
# Unlock state (use with caution)
terraform force-unlock LOCK_ID
# Or wait 15 minutes for lock to expire
```

### Issue: API not enabled
**Fix:**
```bash
# Enable manually
gcloud services enable SERVICE_NAME.googleapis.com --project=PROJECT_ID

# Wait 2-3 minutes, then retry Terraform
```

### Issue: Quota exceeded
**Fix:**
```bash
# Request quota increase in Cloud Console
# Or reduce number of spokes in config.yaml
```

### Issue: nuke.sh fails partway through
**Fix:**
```bash
# Manually delete remaining projects
gcloud projects delete PROJECT_ID --quiet

# Manually delete state bucket
gsutil -m rm -r gs://YOUR_ORG_ID-terraform-state
gsutil rb gs://YOUR_ORG_ID-terraform-state
```

---

## Final Recommendations

1. **Start small:** Test with 1-2 spokes first
2. **Use strict_free:** Minimize costs during learning
3. **Test in sandbox org:** Never test in production org
4. **Monitor costs:** Check billing every 30 minutes
5. **Clean up immediately:** Run `nuke.sh` right after validation
6. **Document findings:** Note any org-specific adjustments needed
7. **Practice teardown:** Test `nuke.sh` multiple times to ensure reliability

**CRITICAL:** Always run `./nuke.sh` after testing to avoid unexpected charges!

---

## Support & Resources

- **GCP Console:** https://console.cloud.google.com
- **Billing Dashboard:** https://console.cloud.google.com/billing
- **IAM Permissions:** https://console.cloud.google.com/iam-admin/iam
- **Terraform Google Provider Docs:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Pricing Calculator:** https://cloud.google.com/products/calculator

---

**Last Updated:** March 1, 2026  
**Testing Environment:** Google Cloud Platform  
**Estimated Testing Cost:** $1-5 for basic validation (teardown immediately)
