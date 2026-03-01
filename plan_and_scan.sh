#!/bin/bash

################################################################################
# GCP Landing Zone - Plan & Security Scan Script (Shift-Left Security)
#
# PURPOSE (Layman's Explanation):
# This script does TWO critical things BEFORE you deploy:
#   1. SECURITY SCAN (tfsec): Looks for security vulnerabilities in your code
#   2. DRY RUN (terraform plan): Shows what will be created/changed/destroyed
#
# Think of this as a "flight simulator + safety inspector" combo.
# You can see what would happen AND catch security issues before they cost money.
#
# COST IMPACT: $0 (no changes made - just preview + security check)
#
# WHAT IT DOES:
# 1. Runs tfsec (security scanner) on all 4 phases
#    - Checks for: public IPs, unencrypted storage, weak IAM, missing logs
#    - Gives you a report with severity: CRITICAL, HIGH, MEDIUM, LOW
# 2. Runs "terraform plan" on all 4 phases in sequence
# 3. Shows you a color-coded preview:
#    - GREEN (+): Resources that will be CREATED
#    - YELLOW (~): Resources that will be MODIFIED
#    - RED (-): Resources that will be DESTROYED
# 4. Counts total changes and gives you a safety summary
#
# HOW TO RUN:
# ./plan_and_scan.sh
#
# TIME: ~3-5 minutes (tfsec adds ~1-2 min)
#
# WHEN TO USE THIS:
# - ALWAYS run this before "terraform apply"
# - Before committing code to Git
# - After making config.yaml changes
# - To catch security issues early (Shift-Left Security)
#
################################################################################

set -e

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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  GCP Landing Zone - Security Scan & Plan (Shift-Left)    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Step 1: Security scanning with tfsec${NC}"
echo -e "${BLUE}Step 2: Terraform plan preview${NC}"
echo ""

# Check if tfsec is installed
if ! command -v tfsec &> /dev/null; then
    echo -e "${RED}✗ tfsec is not installed!${NC}"
    echo ""
    echo -e "${YELLOW}tfsec is a security scanner that finds vulnerabilities BEFORE deployment.${NC}"
    echo -e "${YELLOW}Install it by running: ./check_and_install.sh${NC}"
    echo ""
    exit 1
fi

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

################################################################################
# PHASE 1: SECURITY SCANNING (tfsec)
################################################################################

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}  Phase 1: Security Scanning (tfsec)${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Define phases
PHASES=("0-Bootstrap" "1-Resman" "2-Networking" "3-Projects")
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0
SECURITY_FAILED=false

for phase in "${PHASES[@]}"; do
    echo -e "${YELLOW}Scanning $phase...${NC}"
    
    if [ -d "$phase" ]; then
        cd "$phase"
        
        # Run tfsec and capture output
        # --no-color for easier parsing, --format compact for concise output
        TFSEC_OUTPUT=$(retry_with_backoff tfsec . --no-colour --format compact 2>&1 || true)
        
        # Count severity levels
        CRITICAL_COUNT=$(echo "$TFSEC_OUTPUT" | grep -c "CRITICAL" || echo 0)
        HIGH_COUNT=$(echo "$TFSEC_OUTPUT" | grep -c "HIGH" || echo 0)
        MEDIUM_COUNT=$(echo "$TFSEC_OUTPUT" | grep -c "MEDIUM" || echo 0)
        LOW_COUNT=$(echo "$TFSEC_OUTPUT" | grep -c "LOW" || echo 0)
        
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL_COUNT))
        TOTAL_HIGH=$((TOTAL_HIGH + HIGH_COUNT))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + MEDIUM_COUNT))
        TOTAL_LOW=$((TOTAL_LOW + LOW_COUNT))
        
        if [ $CRITICAL_COUNT -gt 0 ] || [ $HIGH_COUNT -gt 0 ]; then
            echo -e "  ${RED}✗ Found $CRITICAL_COUNT CRITICAL, $HIGH_COUNT HIGH issues${NC}"
            SECURITY_FAILED=true
            
            # Show detailed output for critical/high issues
            if [ ! -z "$TFSEC_OUTPUT" ]; then
                echo -e "${RED}Details:${NC}"
                echo "$TFSEC_OUTPUT" | grep -E "CRITICAL|HIGH" || true
                echo ""
            fi
        elif [ $MEDIUM_COUNT -gt 0 ] || [ $LOW_COUNT -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ Found $MEDIUM_COUNT MEDIUM, $LOW_COUNT LOW issues${NC}"
        else
            echo -e "  ${GREEN}✓ No security issues found${NC}"
        fi
        
        cd ..
    else
        echo -e "  ${BLUE}ℹ Phase directory not found${NC}"
    fi
    
    echo ""
done

echo -e "${MAGENTA}Security Scan Summary:${NC}"
echo -e "  ${RED}CRITICAL:${NC} $TOTAL_CRITICAL"
echo -e "  ${YELLOW}HIGH:${NC} $TOTAL_HIGH"
echo -e "  ${YELLOW}MEDIUM:${NC} $TOTAL_MEDIUM"
echo -e "  ${BLUE}LOW:${NC} $TOTAL_LOW"
echo ""

if [ "$SECURITY_FAILED" = true ]; then
    echo -e "${RED}⚠️  WARNING: Critical or High severity security issues found!${NC}"
    echo -e "${RED}   Review and fix these issues before deploying to production.${NC}"
    echo ""
    echo -e "${YELLOW}Do you want to continue with terraform plan? (y/n)${NC}"
    read -r -n 1 CONTINUE
    echo ""
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Aborted. Fix security issues first.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Security scan passed!${NC}"
fi

echo ""

################################################################################
# PHASE 2: TERRAFORM PLAN
################################################################################

# Check if bootstrap has been run
STATE_BUCKET="${ORG_ID}-terraform-state"

if ! retry_with_backoff gsutil ls "gs://${STATE_BUCKET}" &>/dev/null; then
    echo -e "${YELLOW}⚠️  State bucket not found. Did you run ./bootstrap.sh first?${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Phase 2: Terraform Plan (Dry Run Preview)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

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
    if retry_with_backoff terraform init -reconfigure -input=false &>/dev/null; then
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
    PLAN_OUTPUT=$(retry_with_backoff terraform plan -no-color 2>&1 || true)
    
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
echo -e "${CYAN}║  OVERALL SUMMARY                                          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${MAGENTA}Security Scan Results:${NC}"
echo -e "  ${RED}CRITICAL:${NC} $TOTAL_CRITICAL issues"
echo -e "  ${YELLOW}HIGH:${NC} $TOTAL_HIGH issues"
echo -e "  ${YELLOW}MEDIUM:${NC} $TOTAL_MEDIUM issues"
echo -e "  ${BLUE}LOW:${NC} $TOTAL_LOW issues"
echo ""

if [ ${#FAILED_PHASES[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed Phases:${NC}"
    for phase in "${FAILED_PHASES[@]}"; do
        echo -e "  - $phase"
    done
    echo ""
fi

echo -e "${CYAN}Terraform Plan Results:${NC}"
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
    echo -e "${GREEN}✓ Scan and plan complete. To apply these changes:${NC}"
    echo ""
    echo -e "  ${CYAN}cd 0-Bootstrap && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 1-Resman && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 2-Networking && terraform apply && cd ..${NC}"
    echo -e "  ${CYAN}cd 3-Projects && terraform apply && cd ..${NC}"
    echo ""
    echo -e "  ${BLUE}Or use the all-in-one script:${NC}"
    echo -e "  ${CYAN}./run_all_phases.sh${NC}"
else
    echo -e "${GREEN}✓ No changes needed - infrastructure is up to date!${NC}"
fi

echo ""

# Exit with error if security issues were found and user wants to enforce
if [ "$SECURITY_FAILED" = true ]; then
    echo -e "${YELLOW}Note: Security issues were found but you chose to continue.${NC}"
    echo -e "${YELLOW}Fix these issues before deploying to production!${NC}"
fi
