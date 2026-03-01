# 📖 Brownfield Project Import Guide

This guide explains how to import existing GCP projects into your Landing Zone.

---

## What is Brownfield?

**Greenfield** = Creating brand new projects  
**Brownfield** = Importing projects you already have

---

## When to Use Brownfield

- ✅ You already have a legacy GCP project you want to manage with Terraform
- ✅ You want to migrate an existing project into the landing zone structure
- ✅ You're adopting this infrastructure code for an existing setup

---

## Step 1: Define in config.yaml

```yaml
spokes:
  - name: "my-existing-project"
    type: "brownfield"                    # Key: Use "brownfield"
    existing_project_id: "my-project-123" # Your actual GCP project ID
    cost_profile: "free"                  # or "paid"
    labels:
      env: "legacy"
      department: "engineering"
```

**Key points:**
- `existing_project_id` must match your actual GCP project ID exactly
- Can find project ID in: Cloud Console → Settings (gear icon) → Project settings

---

## Step 2: Deploy Phase 1 (Resman) - PARTIAL

```bash
cd 1-Resman
terraform init -backend-config=backend-config.hcl

# Plan first (don't apply yet!)
terraform plan -out=tfplan
```

**You'll see:**
```
Plan: 3 to add, 0 to change, 0 to destroy

+ google_project.spoke_brownfield["my-existing-project"]
  name = "my-existing-project"
  ...
```

**Do NOT apply yet!** We need to import the existing project first.

---

## Step 3: Terraform Import

This tells Terraform: "I have this project already, please manage it for me."

```bash
# Import the existing project
terraform import google_project.spoke_brownfield["my-existing-project"] my-project-123

# You'll see:
# google_project.spoke_brownfield["my-existing-project"]: Import successful!
```

**Syntax:**
```bash
terraform import google_project.spoke_brownfield[SPOKE_NAME] GCP_PROJECT_ID
```

**Examples:**
```bash
# Single brownfield project
terraform import google_project.spoke_brownfield["legacy"] my-old-project-abc

# Multiple brownfield projects
terraform import google_project.spoke_brownfield["legacy-app"] legacy-app-prod-123
terraform import google_project.spoke_brownfield["legacy-db"] legacy-db-prod-456
terraform import google_project.spoke_brownfield["legacy-api"] legacy-api-prod-789
```

---

## Step 4: Move Project to Folder

Terraform will import the project, but it's still in your organization root. We need to move it to the landing zone folder.

```bash
# In the same 1-Resman directory, run:
terraform apply tfplan
```

**What this does:**
- Moves the imported project to the landing zone folder
- Assigns billing account
- Creates service accounts
- Sets up IAM permissions

**You'll see:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed

Outputs:
spoke_projects = {
  "my-existing-project" = {
    "project_id" = "my-project-123"
    ...
  }
}
```

---

## Step 5: Continue with Phases 2 & 3

```bash
# Back to root
cd ..

# Deploy networking
cd 2-Networking
terraform init -backend-config=backend-config.hcl
terraform apply

# Deploy security/logging
cd ../3-Projects
terraform init -backend-config=backend-config.hcl
terraform apply
```

The brownfield project is now integrated! It has:
- ✅ VPC peered to hub
- ✅ Audit logging configured
- ✅ Budget alerts
- ✅ Org policies applied

---

## Troubleshooting Brownfield

### "Error: project already exists in folder"

**Cause:** The project is already in a folder (or root)  
**Fix:** You can't have a project in two folders. Choose one:

**Option A: Move project in Cloud Console first**
1. Go to Cloud Console → Resource Management → Select Project
2. Move to root (unassign from folder)
3. Then run terraform import

**Option B: Remove from terraform state and re-import**
```bash
terraform state rm google_project.spoke_brownfield["name"]
terraform import google_project.spoke_brownfield["name"] PROJECT_ID
```

### "Error: folder_id cannot be changed"

**Cause:** You're trying to move a project that's already assigned  
**Fix:** Use `lifecycle { ignore_changes = [folder_id] }`

In `1-Resman/main.tf`, modify:
```terraform
resource "google_project" "spoke_brownfield" {
  for_each = {...}

  # ... other config ...
  
  lifecycle {
    ignore_changes = [folder_id]  # Don't move it
  }
}
```

### "Error: billing_account cannot be changed"

**Fix:** Similar to above - add to lifecycle:
```terraform
lifecycle {
  ignore_changes = [billing_account]
}
```

### "terraform import says 'resource already exists in state'"

**Cause:** You already imported it  
**Fix:** Just run terraform apply again (it will succeed)

---

## Verifying the Import

After import, verify everything worked:

```bash
# Check project was imported
terraform state show google_project.spoke_brownfield[your-name]

# Check it has the right attributes
gcloud projects describe my-project-123

# Check it's in the right folder
gcloud projects describe my-project-123 --format="value(parent)"
# Should show: folders/FOLDER_ID (not "organizations/...")
```

---

## Multiple Brownfield Projects

If importing 3 legacy projects:

```yaml
spokes:
  - name: "legacy-app"
    type: "brownfield"
    existing_project_id: "legacy-app-prod"
    cost_profile: "paid"
  
  - name: "legacy-db"
    type: "brownfield"
    existing_project_id: "legacy-db-prod"
    cost_profile: "paid"
  
  - name: "legacy-reporting"
    type: "brownfield"
    existing_project_id: "legacy-reports-prod"
    cost_profile: "free"
```

Then import each:

```bash
cd 1-Resman
terraform import google_project.spoke_brownfield["legacy-app"] legacy-app-prod
terraform import google_project.spoke_brownfield["legacy-db"] legacy-db-prod
terraform import google_project.spoke_brownfield["legacy-reporting"] legacy-reports-prod
terraform apply
```

---

## Mixed Greenfield + Brownfield

You can have both in the same landing zone:

```yaml
spokes:
  # NEW projects
  - name: "sandbox"
    type: "greenfield"
  
  # EXISTING projects
  - name: "production"
    type: "brownfield"
    existing_project_id: "prod-central-xyz"
```

**Workflow:**
```bash
# Greenfield projects are auto-created
# Brownfield projects are imported

cd 1-Resman
terraform plan
# Shows: Create greenfield projects, Import brownfield projects

# For brownfield imports:
terraform import google_project.spoke_brownfield["production"] prod-central-xyz

# For all projects:
terraform apply
```

---

## Rollback / Unmanage Project

If you want to stop managing a brownfield project with Terraform:

```bash
# Remove from Terraform state (but project still exists in GCP)
terraform state rm google_project.spoke_brownfield["project-name"]

# Remove from config.yaml
# Redeploy

# Project remains in GCP, just not managed by Terraform anymore
```

---

## Best Practices

1. ✅ Import one at a time and verify each step
2. ✅ Take backups: `terraform state pull > backup.tfstate`
3. ✅ Use `-target` to only update specific projects: `terraform apply -target google_project.spoke_brownfield["name"]`
4. ✅ Document which projects are brownfield vs greenfield
5. ✅ Test in dev environment first

---

## Common Pattern: Migrate from Manual to Terraform

If you currently manage projects manually:

1. Define all projects in config.yaml (as brownfield)
2. Run: `terraform init`
3. For each project: `terraform import google_project.spoke_brownfield[name] PROJECT_ID`
4. Run: `terraform plan` (should show zero changes if import worked)
5. Run: `terraform apply` to link them into landing zone
6. Future changes go through Terraform (no more manual changes!)

---

## Security Note

⚠️ When importing existing projects:
- Existing IAM bindings stay
- Existing networks stay
- Terraform only *manages* what you tell it to
- If you don't want Terraform changing something, add `lifecycle { ignore_changes = [...] }`

---

For questions, see [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) or [START_HERE.md](START_HERE.md)
