# 🆓 GCP Landing Zone - Pure Free Tier Setup

**Goal:** Deploy a fully functional GCP landing zone for **$0/month**

---

## ✅ **Quick Setup: Copy-Paste Free Tier Config**

### **Step 1: Edit config.yaml**

Replace module sections with this:

```yaml
free_tier_modules:
   enable_scc_standard: true             # ✅ FREE - Security scanning
   enable_iap_access: true               # ✅ FREE - Zero Trust VM access
   enable_org_policies: true             # ✅ FREE - Security guardrails
   enable_observability_baseline: true   # ✅ FREE - Dashboard + CPU alerts
   enable_vpc_service_controls: false    # ✅ FREE feature, advanced setup

chargeable_modules:
   enable_central_logging: false         # ❌ Turn OFF (saves $7/month)
   enable_private_service_connect: false # ❌ Turn OFF (saves $50/month)
   enable_cloud_nat: false               # ❌ Turn OFF (saves $35/month)
   enable_secret_manager: false          # ❌ Turn OFF (saves $1/month)
   enable_centralized_ingress: false     # ❌ Turn OFF (enterprise module)
   enable_egress_inspection: false       # ❌ Turn OFF (enterprise module)
```

### **Step 2: Use ONLY "free" Cost Profile**

In the `spokes` section:

```yaml
spokes:
  - name: "sandbox"
    type: "greenfield"
    cost_profile: "free"  # ✅ This forces e2-micro in us-central1
    labels:
      env: "dev"
      department: "testing"
      cost-center: "eng-testing"
```

Subnet ranges are now auto-assigned by Terraform IPAM using `cidrsubnet()`.

**🚨 IMPORTANT:** Do NOT add more spokes unless you understand the costs!

### **Step 3: Set Budget Alert to Catch ANY Charges**

```yaml
budget_alert_threshold: 0.01  # Alerts you if cost exceeds $0.01
```

---

## 📋 **What You Get for FREE**

| Feature | Included | Notes |
|---------|----------|-------|
| ✅ **1x e2-micro VM** | Yes | 24/7 in us-central1 |
| ✅ **30GB Disk** | Yes | Standard persistent disk |
| ✅ **Hub-Spoke Network** | Yes | VPC peering is free |
| ✅ **Firewall Rules** | Yes | Unlimited free |
| ✅ **Security Scanning** | Yes | SCC STANDARD tier |
| ✅ **IAP Access** | Yes | Zero Trust browser SSH |
| ✅ **Org Policies** | Yes | Security guardrails |
| ✅ **Budget Alerts** | Yes | Email notifications |

---

## ⚠️ **What's DISABLED (To Stay Free)**

| Feature | Why Disabled | Alternative |
|---------|-------------|------------|
| ❌ **Central Logging** | Costs $7/month | Use GCP Console logs (free) |
| ❌ **Cloud NAT** | Costs $35/month | Assign VMs public IPs instead |
| ❌ **Private Service Connect** | Costs $50/month | Use public API endpoints |
| ❌ **Secret Manager** | Costs $1/month | Store secrets in env vars (less secure) |

---

## 🎯 **Free Tier Rules (MUST Follow)**

1. ✅ **Deploy ONLY 1 VM**
   - More VMs = charges

2. ✅ **Use ONLY us-central1 region**
   - Other regions charge from day 1

3. ✅ **Keep disk ≤ 30GB**
   - More disk = charges

4. ✅ **Limit outbound data to 1GB/month**
   - More data = $0.12/GB

5. ✅ **Use Standard networking tier**
   - Premium tier costs extra

---

## 🚀 **Deployment Steps**

```bash
# 1. Check tools
./check_and_install.sh

# 2. Authenticate
gcloud auth login
gcloud auth application-default login

# 3. Set up foundation
./bootstrap.sh

# 4. Preview (check for costs!)
./plan_and_scan.sh

# 5. Deploy
cd 0-Bootstrap && terraform apply && cd ..
cd 1-Resman && terraform apply && cd ..
cd 2-Networking && terraform apply && cd ..
cd 3-Projects && terraform apply && cd ..
```

---

## 📊 **Verify Zero Cost**

After deployment, run:

```bash
gcloud billing accounts list
```

Then check:
https://console.cloud.google.com/billing

**Look for:**
- ✅ $0.00 current charges
- ✅ No forecasted charges
- ✅ Budget alert email received (at $0.01)

---

## 🛑 **Stop All Costs Immediately**

If you see ANY charges:

```bash
./nuke.sh
```

This destroys EVERYTHING and stops all charges.

---

## ❓ **FAQ**

### **Q: Can I add more VMs?**
A: Only 1 e2-micro is free. Additional VMs cost ~$5-10/month each.

### **Q: Can I use other regions?**
A: Free tier ONLY works in us-central1, us-west1, or us-east1.

### **Q: What if I need logging?**
A: Cloud Logging Console (free) or export to your own BigQuery (free 10GB).

### **Q: Do I need Cloud NAT?**
A: No. Assign VMs public IPs instead (free, but less secure).

### **Q: What about Secret Manager?**
A: It's only $1/month for 20 secrets. Highly recommended for security.

---

## 💡 **Pro Tips**

1. **Use IAP instead of public IPs**
   - More secure, still FREE

2. **Set budget alert to $0.01**
   - Catches charges immediately

3. **Review billing weekly**
   - Go to: https://console.cloud.google.com/billing

4. **Keep 1 spoke only**
   - More spokes = more complexity

5. **Use GCP free tier pricing calculator**
   - https://cloud.google.com/products/calculator

---

## 🎓 **Summary**

| Configuration | Cost | Security | Compliance |
|--------------|------|----------|------------|
| **This Free Setup** | 🆓 $0 | ⭐⭐⭐ Good | ⭐⭐ Basic |
| **+Logging+Secrets** | 🟡 $8 | ⭐⭐⭐⭐ Better | ⭐⭐⭐⭐ Full |
| **+NAT+HA** | 🔴 $150 | ⭐⭐⭐⭐⭐ Best | ⭐⭐⭐⭐⭐ Enterprise |

**Recommendation:** Start FREE, then upgrade features as needed.

---

## 📚 **References**

- GCP Always Free Tier: https://cloud.google.com/free
- Pricing Calculator: https://cloud.google.com/products/calculator
- e2-micro Specs: https://cloud.google.com/compute/docs/machine-types#e2-micro
- Free Tier FAQ: https://cloud.google.com/free/docs/free-cloud-features

---

**Last Updated:** March 1, 2026  
**Maintained By:** Terraform GCP Landing Zone Team
