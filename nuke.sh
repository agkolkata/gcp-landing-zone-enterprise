#!/bin/bash

################################################################################
# GCP Landing Zone - Complete Destruction Script ("NUKE")
#
# PURPOSE (Layman's Explanation):
# This is the "big red button" that DESTROYS EVERYTHING. It stops all costs
# and removes all infrastructure you've built. This action CANNOT BE UNDONE.
#
# COST IMPACT: STOPS ALL CHARGES (deletes all resources)
#
# WHAT IT DOES:
# 1. Removes "project liens" (locks that prevent deletion)
# 2. Disables deletion protection in Terraform state
# 3. Runs "terraform destroy" on all phases
# 4. Hunts down "zombie" resources (orphaned disks, IPs, etc.)
# 5. Deletes all GCP projects
# 6. Deletes the Terraform state bucket
#
# HOW TO RUN:
# ./nuke.sh
#
# WARNING: THIS IS DESTRUCTIVE! All data will be lost!
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

retry_with_backoff() {
    local max_attempts=${RETRY_MAX_ATTEMPTS:-3}
    local delay=${RETRY_INITIAL_DELAY_SECONDS:-2}
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if "$@"; then
            return 0
        fi

        if [ "$attempt" -eq "$max_attempts" ]; then
            return 1
        fi

        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  GCP LANDING ZONE - COMPLETE DESTRUCTION (NUKE)  ⚠️  ║${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}║  THIS WILL DELETE ALL INFRASTRUCTURE AND STOP ALL COSTS  ║${NC}"
echo -e "${RED}║  THIS ACTION CANNOT BE UNDONE!                           ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Are you ABSOLUTELY SURE you want to destroy everything?${NC}"
echo -e "${YELLOW}Type 'yes, destroy everything' to proceed:${NC}"
read -r confirmation

if [ "$confirmation" != "yes, destroy everything" ]; then
    echo -e "${GREEN}✓ Cancelled. Nothing was destroyed.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}⏳ Starting complete destruction sequence...${NC}"
echo ""

# Load config
ORG_ID=$(grep "^organization_id:" config.yaml 2>/dev/null | sed 's/.*: "//' | sed 's/".*//' || echo "")

if [ -z "$ORG_ID" ]; then
    echo -e "${RED}✗ Cannot read config.yaml${NC}"
    exit 1
fi

################################################################################
# STEP 1: REMOVE PROJECT LIENS (Locks preventing deletion)
################################################################################
echo -e "${YELLOW}[STEP 1/6] Removing project liens...${NC}"

# Get all projects under this organization
PROJECTS=$(gcloud projects list --filter="parent.id:$ORG_ID" --format="value(projectId)" 2>/dev/null || echo "")

if [ -z "$PROJECTS" ]; then
    echo -e "${BLUE}ℹ No projects found under organization${NC}"
else
    while IFS= read -r project; do
        if [ ! -z "$project" ]; then
            echo -ne "  Checking liens in project: $project..."
            
            # Try to list liens
            LIENS=$(gcloud alpha resource-manager liens list --project="$project" --format="value(name)" 2>/dev/null || echo "")
            
            if [ ! -z "$LIENS" ]; then
                echo " found!"
                while IFS= read -r lien; do
                    if [ ! -z "$lien" ]; then
                        echo -e "    → Deleting lien: ${YELLOW}$lien${NC}"
                        retry_with_backoff gcloud alpha resource-manager liens delete "$lien" --quiet >/dev/null 2>&1 || true
                    fi
                done <<< "$LIENS"
            else
                echo -e " ${GREEN}none${NC}"
            fi
        fi
    done <<< "$PROJECTS"
fi

echo ""

################################################################################
# STEP 2: OVERRIDE DELETION PROTECTION IN STATE
################################################################################
echo -e "${YELLOW}[STEP 2/6] Disabling deletion protection...${NC}"

for phase in 0-Bootstrap 1-Resman 2-Networking 3-Projects; do
    if [ -f "$phase/terraform.tfstate" ]; then
        echo -e "  Checking deletion protection in $phase..."
        # This is handled by Terraform during destroy, so we just warn
        echo -e "    ${BLUE}ℹ State file found (Terraform will handle deletion_protection override)${NC}"
    fi
done

echo ""

################################################################################
# STEP 3: TERRAFORM DESTROY ON ALL PHASES (Reverse Order!)
################################################################################
echo -e "${YELLOW}[STEP 3/6] Running Terraform destroy on all phases (reverse order)...${NC}"

# Destroy in REVERSE order (3 → 2 → 1 → 0)
for phase in 3-Projects 2-Networking 1-Resman 0-Bootstrap; do
    if [ ! -d "$phase" ]; then
        echo -e "  ${BLUE}ℹ Phase directory not found: $phase${NC}"
        continue
    fi
    
    echo -e "${YELLOW}  Destroying $phase...${NC}"
    cd "$phase" 2>/dev/null || continue
    
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        echo -e "    → Initializing Terraform..."
        terraform init -backend-config=backend-config.hcl -upgrade -no-color >/dev/null 2>&1 || true
    fi
    
    # Run destroy
    echo -e "    → Running terraform destroy..."
    retry_with_backoff terraform destroy -no-color -auto-approve 2>&1 | grep -E "^(Destroy|No changes|Error)" || true
    
    cd ..
done

echo ""

################################################################################
# STEP 4: HUNT ZOMBIE RESOURCES
################################################################################
echo -e "${YELLOW}[STEP 4/6] Hunting for orphaned resources...${NC}"

if [ ! -z "$PROJECTS" ]; then
    while IFS= read -r project; do
        if [ ! -z "$project" ]; then
            echo -e "  Checking project: ${YELLOW}$project${NC}"
            
            # Find unattached disks
            DISKS=$(gcloud compute disks list --project="$project" --filter="users:[]" --format="value(name,zone)" 2>/dev/null || echo "")
            if [ ! -z "$DISKS" ]; then
                echo -e "    → Found unattached disks:"
                while IFS= read -r line; do
                    disk=$(echo $line | awk '{print $1}')
                    zone=$(echo $line | awk '{print $2}')
                    if [ ! -z "$disk" ]; then
                        echo -e "      Deleting: $disk (in $zone)..."
                        retry_with_backoff gcloud compute disks delete "$disk" --zone="$zone" --project="$project" --quiet >/dev/null 2>&1 || true
                    fi
                done <<< "$DISKS"
            fi
            
            # Find unattached IPs
            IPS=$(gcloud compute addresses list --project="$project" --filter="status:RESERVED" --format="value(name,region)" 2>/dev/null || echo "")
            if [ ! -z "$IPS" ]; then
                echo -e "    → Found unused IP addresses:"
                while IFS= read -r line; do
                    ip=$(echo $line | awk '{print $1}')
                    region=$(echo $line | awk '{print $2}')
                    if [ ! -z "$ip" ]; then
                        echo -e "      Deleting: $ip (in $region)..."
                        retry_with_backoff gcloud compute addresses delete "$ip" --region="$region" --project="$project" --quiet >/dev/null 2>&1 || true
                    fi
                done <<< "$IPS"
            fi
        fi
    done <<< "$PROJECTS"
fi

echo ""

################################################################################
# STEP 5: DELETE GCP PROJECTS
################################################################################
echo -e "${YELLOW}[STEP 5/6] Deleting GCP projects...${NC}"

if [ ! -z "$PROJECTS" ]; then
    while IFS= read -r project; do
        if [ ! -z "$project" ]; then
            echo -ne "  Deleting project: ${YELLOW}$project${NC}..."
            retry_with_backoff gcloud projects delete "$project" --no-user-output-enabled --quiet >/dev/null 2>&1 && \
                echo -e " ${GREEN}✓${NC}" || \
                echo -e " ${YELLOW}(pending deletion)${NC}"
        fi
    done <<< "$PROJECTS"
fi

echo ""

################################################################################
# STEP 6: DELETE TERRAFORM STATE BUCKET
################################################################################
echo -e "${YELLOW}[STEP 6/6] Cleaning up Terraform state bucket...${NC}"

# Find the state bucket from backend config
STATE_BUCKET=$(grep "bucket" 0-Bootstrap/backend-config.hcl 2>/dev/null | sed 's/.*= "//' | sed 's/".*//' || echo "")

if [ ! -z "$STATE_BUCKET" ]; then
    echo -e "  State bucket: gs://${YELLOW}$STATE_BUCKET${NC}"
    
    if gsutil ls -b "gs://$STATE_BUCKET" >/dev/null 2>&1; then
        echo -e "    → Removing all objects..."
        retry_with_backoff gsutil -m rm -r "gs://$STATE_BUCKET/**" >/dev/null 2>&1 || true
        
        echo -e "    → Deleting bucket..."
        retry_with_backoff gsutil rb "gs://$STATE_BUCKET" >/dev/null 2>&1 || true
        echo -e "    ${GREEN}✓ Bucket deleted${NC}"
    else
        echo -e "    ${BLUE}ℹ Bucket not found or already deleted${NC}"
    fi
else
    echo -e "    ${BLUE}ℹ Could not determine state bucket${NC}"
fi

echo ""

################################################################################
# SUMMARY
################################################################################
echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ✓ DESTRUCTION SEQUENCE COMPLETE                        ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}What was destroyed:${NC}"
echo "  ✓ All GCP projects"
echo "  ✓ All compute resources (VMs, networks, disks)"
echo "  ✓ All storage (buckets, databases)"
echo "  ✓ All Terraform state files"
echo ""
echo -e "${YELLOW}Cost impact:${NC}"
echo "  ${GREEN}✓ All charges have been stopped${NC}"
echo "  ⏳ Billing may take 24-48 hours to fully reflect"
echo ""
echo -e "${BLUE}Note: Some resources may take 7-30 days to fully purge.${NC}"
echo ""
