# START HERE: Dummies Guide for This Landing Zone

## Layman's Map
- `config.yaml`: The control center. You change this file to decide what gets built.
- `check_and_install.sh`: Installs and verifies required tools.
- `bootstrap.sh`: Prepares Google Cloud and Terraform state bucket.
- `plan_and_scan.sh`: Runs security scan (`tfsec`) and dry-run plan.
- `nuke.sh`: Destroys everything and cleans leftovers.
- `0-Bootstrap/`: Org-level setup (APIs, service account, state bucket).
- `1-Resman/`: Project lifecycle (greenfield, brownfield adopt, brownfield reference metadata).
- `2-Networking/`: Hub-and-spoke VPC, peering, brownfield references, workload foundations, IPAM.
- `3-Projects/`: Budgets and governance controls.

## Pre-Flight IAM Checklist
Use an account with these permissions before running anything:
- `roles/resourcemanager.organizationAdmin`
- `roles/resourcemanager.folderAdmin`
- `roles/billing.admin`
- `roles/iam.securityAdmin`
- `roles/serviceusage.serviceUsageAdmin`

Quick verification command:

```bash
gcloud auth list
```

## Understand Cost Modes (Very Important)
- `strict_free`: Auto-corrector silently disables chargeable features for that spoke.
- `custom_mix`: Respects your YAML toggles for a hybrid setup.

## Exact VS Code Terminal Instructions
Open VS Code Terminal (`Ctrl+``) and run exactly:

```bash
./check_and_install.sh
```

```bash
gcloud auth login
gcloud auth application-default login
```

```bash
./bootstrap.sh
```

```bash
./plan_and_scan.sh
```

If plan output looks correct:

```bash
cd 0-Bootstrap
terraform init -backend-config=backend-config.hcl
terraform apply -auto-approve
cd ../1-Resman
terraform init -backend-config=backend-config.hcl
terraform apply -auto-approve
cd ../2-Networking
terraform init -backend-config=backend-config.hcl
terraform apply -auto-approve
cd ../3-Projects
terraform init -backend-config=backend-config.hcl
terraform apply -auto-approve
cd ..
```

## Brownfield Modes
- `brownfield_adopt`: Terraform takes ownership of existing project using native `import {}` blocks.
- `brownfield_reference`: Terraform reads an existing network via data source and peers to it without managing it.

## Workload Foundations
In `config.yaml` under a spoke's `workload_foundations`:
- `enable_gcve_networking`: Adds GCVE Private Service Access scaffolding.
- `enable_gke_multi_cloud`: Adds Pod/Service secondary ranges and enables required APIs.
- `enable_migration_factory`: Adds migration firewall scaffolding and enables migration APIs.

## Safety and Rollback
- To stop before deployment: only run `./plan_and_scan.sh`.
- To destroy everything:

```bash
./nuke.sh
```

## Troubleshooting Quick Wins
- `terraform validate` fails with provider lock mismatch:

```bash
terraform init -upgrade
```

- API enablement propagation delays: rerun the same command; scripts already retry with exponential backoff.
