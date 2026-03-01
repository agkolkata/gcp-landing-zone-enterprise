#!/bin/bash

################################################################################
# GCP Landing Zone - Automated Deployment Script
#
# PURPOSE (Layman's Explanation):
# This script runs all 4 Terraform phases automatically.
# Instead of manually typing commands for each phase, you just run this once.
# It initializes, plans, and applies all phases in the correct order.
#
# COST IMPACT: Creates all infrastructure (depends on config.yaml settings)
#
# HOW TO RUN:
# ./run_all_phases.sh
#
# TIME: ~20-30 minutes for first deployment
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GCP Landing Zone - Automated Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Verify files exist
if [ ! -f "config.yaml" ]; then
    echo -e "${RED}✗ config.yaml not found!${NC}"
    exit 1
fi

if [ ! -f "bootstrap.sh" ]; then
    echo -e "${RED}✗ bootstrap.sh not found!${NC}"
    exit 1
fi

# Read org ID for summary commands at the end
ORG_ID=$(grep "^organization_id:" config.yaml | sed 's/.*: "//' | sed 's/".*//')
if [ -z "$ORG_ID" ] || [ "$ORG_ID" == "YOUR_ORG_ID" ]; then
    ORG_ID="YOUR_ORG_ID"
fi

echo -e "${YELLOW}Pre-deployment checks:${NC}"
echo -ne "  Checking gcloud... "
command -v gcloud >/dev/null && echo -e "${GREEN}✓${NC}" || (echo -e "${RED}✗${NC}" && exit 1)

echo -ne "  Checking terraform... "
command -v terraform >/dev/null && echo -e "${GREEN}✓${NC}" || (echo -e "${RED}✗${NC}" && exit 1)

echo ""

################################################################################
# CRITICAL: Run bootstrap.sh FIRST (before Terraform)
# This creates locals.tf and backend-config.hcl that Terraform needs
################################################################################
echo -e "${YELLOW}[PRE-TERRAFORM] Running bootstrap.sh setup script...${NC}"
echo -e "${BLUE}This creates locals.tf and backend-config.hcl files needed by all phases.${NC}"
echo ""

if [ ! -f "bootstrap.sh" ]; then
    echo -e "${RED}✗ bootstrap.sh not found!${NC}"
    exit 1
fi

chmod +x bootstrap.sh
./bootstrap.sh || {
    echo -e "${RED}✗ Bootstrap setup failed!${NC}"
    exit 1
}

echo ""
echo -e "${YELLOW}⏳ Starting Terraform deployment sequence...${NC}"
echo -e "${BLUE}This will take 20-30 minutes. Do NOT interrupt!${NC}"
echo ""

# Function to deploy a phase
deploy_phase() {
    local phase_num=$1
    local phase_name=$2
    local phase_dir="$phase_num-$phase_name"
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}[PHASE $phase_num] Deploying $phase_name...${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$phase_dir" ]; then
        echo -e "${RED}✗ Directory not found: $phase_dir${NC}"
        exit 1
    fi
    
    cd "$phase_dir"
    
    # Initialize Terraform
    echo -e "${BLUE}→ Initializing Terraform...${NC}"
    terraform init \
        -backend-config=backend-config.hcl \
        -upgrade \
        -no-color
    
    echo ""
    
    # Plan
    echo -e "${BLUE}→ Planning changes...${NC}"
    terraform plan \
        -no-color \
        -out=tfplan
    
    echo ""
    
    # Show what will be created
    echo -e "${YELLOW}→ Resources to be created/modified:${NC}"
    terraform show -no-color tfplan | grep "will be" | head -20 || true
    
    echo ""
    
    # Apply
    echo -e "${YELLOW}Confirming deployment of phase $phase_num...${NC}"
    read -p "Type 'yes' to proceed, or 'no' to skip: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Skipping phase $phase_num${NC}"
        cd ..
        return 1
    fi
    
    echo -e "${BLUE}→ Applying Terraform...${NC}"
    terraform apply \
        -no-color \
        tfplan
    
    # Show outputs
    echo ""
    echo -e "${GREEN}✓ Phase $phase_num complete!${NC}"
    echo -e "${BLUE}Outputs:${NC}"
    terraform output -no-color | head -15 || true
    
    cd ..
    echo ""
}

################################################################################
# PHASE 0: BOOTSTRAP
################################################################################
deploy_phase 0 "Bootstrap" || exit 1

################################################################################
# PHASE 1: RESMAN
################################################################################
deploy_phase 1 "Resman" || exit 1

################################################################################
# PHASE 2: NETWORKING
################################################################################
deploy_phase 2 "Networking" || exit 1

################################################################################
# PHASE 3: PROJECTS
################################################################################
deploy_phase 3 "Projects" || exit 1

################################################################################
# SUMMARY & NEXT STEPS
################################################################################
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓✓✓ DEPLOYMENT COMPLETE! ✓✓✓${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}What was created:${NC}"
echo "  ✓ Terraform service account & permissions"
echo "  ✓ GCP project folder structure"
echo "  ✓ Spoke projects (greenfield & brownfield)"
echo "  ✓ Hub VPC network"
echo "  ✓ Spoke VPC networks (peered to hub)"
echo "  ✓ Firewall rules"
echo "  ✓ Cloud Logging (audit logs → BigQuery)"
echo "  ✓ Budget alerts ($1/month per spoke)"
echo "  ✓ Organizational policies (security guardrails)"
echo "  ✓ Security Command Center (if enabled)"
echo ""
echo -e "${YELLOW}Verify deployment:${NC}"
echo "  gcloud projects list"
echo "  gcloud compute networks list"
echo "  go to https://console.cloud.google.com/billing"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Deploy first VM in the infrastructure:"
echo "     gcloud compute instances create my-vm --zone us-central1-a"
echo "  2. Check audit logs:"
echo "     bq query --nouse_legacy_sql 'SELECT * FROM \`${ORG_ID}.audit_logs.cloudaudit_googleapis_com_activity\` LIMIT 10'"
echo "  3. Review organization policies:"
echo "     gcloud resource-manager org-policies list"
echo ""
echo -e "${BLUE}For detailed docs, see: START_HERE.md${NC}"
echo ""
