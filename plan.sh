#!/bin/bash

################################################################################
# GCP Landing Zone - Plan Script (Dry Run)
#
# PURPOSE (Layman's Explanation):
# This is the "preview mode" that shows you EXACTLY what Terraform will create,
# change, or destroy WITHOUT actually doing it. Think of it as a "flight
# simulator" - you can safely see what would happen before you commit.
#
# COST IMPACT: $0 (no changes made - just a preview)
#
# WHAT IT DOES:
# 1. Runs "terraform plan" on all 4 phases in sequence
# 2. Shows you a color-coded preview:
#    - GREEN (+): Resources that will be CREATED
#    - YELLOW (~): Resources that will be MODIFIED
#    - RED (-): Resources that will be DESTROYED
# 3. Counts total changes and gives you a safety summary
#
# HOW TO RUN:
# ./plan.sh
#
# TIME: ~2-3 minutes
#
# WHEN TO USE THIS:
# - Before running "terraform apply" (always preview first!)
# - To verify your config.yaml changes
# - To understand what will happen without risk
# - To catch mistakes before they cost money
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  GCP Landing Zone - Terraform Plan (Dry Run Preview)     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}This will show you what Terraform WOULD do, without making changes.${NC}"
echo ""

# Load config
if [ ! -f "config.yaml" ]; then
    echo -e "${RED}✗ config.yaml not found!${NC}"
    exit 1
fi

ORG_ID=$(grep "^organization_id:" config.yaml | sed 's/.*: "//' | sed 's/".*//')

if [ -z "$ORG_ID" ] || [ "$ORG_ID" == "YOUR_ORG_ID" ]; then
    echo -e "${RED}✗ Please configure config.yaml first${NC}"
    exit 1
fi

# Check if bootstrap has been run
STATE_BUCKET="${ORG_ID}-terraform-state"

if ! gsutil ls "gs://${STATE_BUCKET}" &>/dev/null; then
    echo -e "${YELLOW}⚠️  State bucket not found. Did you run ./bootstrap.sh first?${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""

# Define phases
PHASES=("0-Bootstrap" "1-Resman" "2-Networking" "3-Projects")
TOTAL_ADDITIONS=0
TOTAL_CHANGES=0
TOTAL_DESTRUCTIONS=0
FAILED_PHASES=()

for phase in "${PHASES[@]}"; do
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Planning Phase: $phase${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    cd "$phase"
    
    # Initialize if needed
    echo -e "${BLUE}Initializing Terraform...${NC}"
    if terraform init -reconfigure -input=false &>/dev/null; then
        echo -e "${GREEN}✓ Initialized${NC}"
    else
        echo -e "${RED}✗ Initialization failed${NC}"
        FAILED_PHASES+=("$phase")
        cd ..
        continue
    fi
    
    echo ""
    echo -e "${CYAN}Running terraform plan...${NC}"
    echo ""
    
    # Run plan and capture output
    PLAN_OUTPUT=$(terraform plan -no-color 2>&1 || true)
    
    # Display the plan
    echo "$PLAN_OUTPUT"
    
    # Parse plan summary
    if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
        echo ""
        echo -e "${GREEN}✓ No changes for this phase${NC}"
    elif echo "$PLAN_OUTPUT" | grep -q "Plan:"; then
        # Extract numbers from "Plan: X to add, Y to change, Z to destroy"
        ADD=$(echo "$PLAN_OUTPUT" | grep "Plan:" | sed -n 's/.*Plan: \([0-9]*\) to add.*/\1/p' || echo 0)
        CHANGE=$(echo "$PLAN_OUTPUT" | grep "Plan:" | sed -n 's/.*, \([0-9]*\) to change.*/\1/p' || echo 0)
        DESTROY=$(echo "$PLAN_OUTPUT" | grep "Plan:" | sed -n 's/.*, \([0-9]*\) to destroy.*/\1/p' || echo 0)
        
        TOTAL_ADDITIONS=$((TOTAL_ADDITIONS + ADD))
        TOTAL_CHANGES=$((TOTAL_CHANGES + CHANGE))
        TOTAL_DESTRUCTIONS=$((TOTAL_DESTRUCTIONS + DESTROY))
        
        echo ""
        echo -e "${CYAN}Phase Summary:${NC}"
        echo -e "  ${GREEN}+${NC} $ADD to add"
        echo -e "  ${YELLOW}~${NC} $CHANGE to change"
        echo -e "  ${RED}-${NC} $DESTROY to destroy"
    elif echo "$PLAN_OUTPUT" | grep -q "Error"; then
        echo ""
        echo -e "${RED}✗ Plan failed with errors${NC}"
        FAILED_PHASES+=("$phase")
    fi
    
    cd ..
    echo ""
done

################################################################################
# Final Summary
################################################################################

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  OVERALL PLAN SUMMARY                                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ${#FAILED_PHASES[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed Phases:${NC}"
    for phase in "${FAILED_PHASES[@]}"; do
        echo -e "  - $phase"
    done
    echo ""
fi

echo -e "Total changes across all phases:"
echo -e "  ${GREEN}+${NC} $TOTAL_ADDITIONS resources to add"
echo -e "  ${YELLOW}~${NC} $TOTAL_CHANGES resources to change"
echo -e "  ${RED}-${NC} $TOTAL_DESTRUCTIONS resources to destroy"
echo ""

if [ $TOTAL_DESTRUCTIONS -gt 0 ]; then
    echo -e "${RED}⚠️  WARNING: This plan will DESTROY resources!${NC}"
    echo -e "${RED}   Review carefully before applying.${NC}"
    echo ""
fi

if [ $TOTAL_ADDITIONS -gt 0 ] || [ $TOTAL_CHANGES -gt 0 ]; then
    echo -e "${GREEN}✓ Plan complete. To apply these changes:${NC}"
    echo ""
    echo -e "  ${CYAN}cd 0-Bootstrap && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 1-Resman && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 2-Networking && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 3-Projects && terraform apply && cd ..${NC}"
    echo ""
    echo -e "${BLUE}Or use the convenient wrapper:${NC}"
    echo -e "  ${CYAN}./run_all_phases.sh${NC}"
else
    echo -e "${GREEN}✓ No changes needed. Infrastructure is up to date.${NC}"
fi

echo ""
