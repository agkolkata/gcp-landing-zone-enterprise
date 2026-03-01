#!/bin/bash

################################################################################
# GCP Landing Zone - Bootstrap Script
#
# PURPOSE (Layman's Explanation):
# This is the "setup wizard" that prepares Google Cloud for Terraform.
# It logs you into Google Cloud, enables the APIs you need, and creates the
# "vault" (GCS bucket) where Terraform stores backups of your infrastructure.
#
# COST IMPACT: $0 (setup only - no compute resources)
#
# WHAT IT DOES:
# 1. Logs you into Google Cloud (opens browser for authentication)
# 2. Sets your default project/organization
# 3. Enables APIs in correct order (with delays to prevent race conditions)
# 4. Creates a GCS bucket for Terraform remote state
# 5. Enables state versioning and locking
# 6. Creates a locals.tf file for consistent settings
#
# HOW TO RUN:
# ./bootstrap.sh
#
# TIME: ~5 minutes (includes intentional waits for API propagation)
#
################################################################################

set -e  # Exit on any error

# Colors for output
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

        echo -e "${YELLOW}  Attempt ${attempt}/${max_attempts} failed. Retrying in ${delay}s...${NC}"
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GCP Landing Zone - Bootstrap Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Load config.yaml
if [ ! -f "config.yaml" ]; then
    echo -e "${RED}✗ config.yaml not found!${NC}"
    echo "Please run: cp config.yaml.template config.yaml"
    exit 1
fi

# Parse config.yaml (basic YAML parsing)
ORG_ID=$(grep "^organization_id:" config.yaml | sed 's/.*: "//' | sed 's/".*//')
BILLING=$(grep "^billing_account:" config.yaml | sed 's/.*: "//' | sed 's/".*//')
REGION=$(grep "^default_region:" config.yaml | sed 's/.*: "//' | sed 's/".*//')
HAS_GKE_MULTICLOUD=false
HAS_MIGRATION_FACTORY=false
HAS_GCVE_FOUNDATION=false

if grep -q "enable_gke_multi_cloud: true" config.yaml; then
    HAS_GKE_MULTICLOUD=true
fi

if grep -q "enable_migration_factory: true" config.yaml; then
    HAS_MIGRATION_FACTORY=true
fi

if grep -q "enable_gcve_networking: true" config.yaml; then
    HAS_GCVE_FOUNDATION=true
fi

echo -e "${YELLOW}Configuration loaded:${NC}"
echo "  Organization ID: $ORG_ID"
echo "  Billing Account: $BILLING"
echo "  Default Region: $REGION"
echo ""

# Validate config
if [ -z "$ORG_ID" ] || [ "$ORG_ID" == "\${ORG_ID}" ]; then
    echo -e "${RED}✗ Organization ID not set in config.yaml${NC}"
    exit 1
fi

if [ "$ORG_ID" == "YOUR_ORG_ID" ]; then
    echo -e "${RED}✗ Organization ID is still placeholder value (YOUR_ORG_ID)${NC}"
    exit 1
fi

if [ -z "$BILLING" ] || [ "$BILLING" == "\${BILLING}" ]; then
    echo -e "${RED}✗ Billing Account not set in config.yaml${NC}"
    exit 1
fi

if [ "$BILLING" == "YOUR_BILLING_ID" ]; then
    echo -e "${RED}✗ Billing account is still placeholder value (YOUR_BILLING_ID)${NC}"
    exit 1
fi

################################################################################
# STEP 1: AUTHENTICATE TO GOOGLE CLOUD
################################################################################
echo -e "${YELLOW}[STEP 1/5] Authenticating to Google Cloud...${NC}"

if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    CURRENT_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "${GREEN}✓ Already authenticated as: $CURRENT_ACCOUNT${NC}"
else
    echo -e "${YELLOW}Opening browser for Google Cloud authentication...${NC}"
    retry_with_backoff gcloud auth login --no-browser --force
fi

# Set organization level
retry_with_backoff gcloud config set project "$ORG_ID" >/dev/null 2>&1 || true

echo ""

################################################################################
# STEP 2: ENABLE REQUIRED APIS (WITH DELAYS)
################################################################################
echo -e "${YELLOW}[STEP 2/5] Enabling Google Cloud APIs...${NC}"
echo -e "${BLUE}Note: APIs take time to propagate. Intentional 30-second waits prevent errors.${NC}"
echo ""

# Define APIs in order (this order matters!)
# Billing API is the foundation for all others
declare -a APIS=(
    "resource.googleapis.com|Resource Manager API|30"
    "billing.googleapis.com|Billing API|30"
    "servicemanagement.googleapis.com|Service Management API|30"
    "cloudresourcemanager.googleapis.com|Cloud Resource Manager|30"
    "compute.googleapis.com|Compute Engine API|30"
    "storage-api.googleapis.com|Cloud Storage API|30"
    "storage.googleapis.com|Cloud Storage|30"
    "cloudfunctions.googleapis.com|Cloud Functions API|30"
    "logging.googleapis.com|Cloud Logging API|30"
    "monitoring.googleapis.com|Cloud Monitoring API|30"
    "bigquery.googleapis.com|BigQuery API|30"
    "iap.googleapis.com|Cloud IAP API|30"
    "secretmanager.googleapis.com|Secret Manager API|30"
    "securitycenter.googleapis.com|Security Command Center API|30"
)

if [ "$HAS_GKE_MULTICLOUD" = true ]; then
    APIS+=("gkehub.googleapis.com|GKE Hub API|30")
    APIS+=("anthos.googleapis.com|Anthos API|30")
fi

if [ "$HAS_MIGRATION_FACTORY" = true ]; then
    APIS+=("vmmigration.googleapis.com|VM Migration API|30")
    APIS+=("storagetransfer.googleapis.com|Storage Transfer API|30")
fi

if [ "$HAS_GCVE_FOUNDATION" = true ]; then
    APIS+=("vmwareengine.googleapis.com|VMware Engine API|30")
    APIS+=("servicenetworking.googleapis.com|Service Networking API|30")
fi

for api_info in "${APIS[@]}"; do
    IFS='|' read -r api_code api_name wait_time <<< "$api_info"
    
    echo -ne "${YELLOW}Enabling ${api_name}...${NC}"
    
    if retry_with_backoff gcloud services enable "$api_code" --format=none >/dev/null 2>&1 || true; then
        echo -e " ${GREEN}✓${NC}"
    else
        echo -e " ${YELLOW}(already enabled or pending)${NC}"
    fi
    
    echo -e "${BLUE}  → Waiting ${wait_time}s for API propagation...${NC}"
    sleep $wait_time
done

echo ""

################################################################################
# STEP 3: CREATE GSC BUCKET FOR TERRAFORM STATE
################################################################################
echo -e "${YELLOW}[STEP 3/5] Creating GCS bucket for Terraform state...${NC}"

# Generate unique bucket name (based on org_id for consistency)
STATE_BUCKET="${ORG_ID}-terraform-state"

echo "Bucket name: $STATE_BUCKET"

# Check if bucket already exists
if gsutil ls -b "gs://$STATE_BUCKET" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Bucket already exists: gs://$STATE_BUCKET${NC}"
else
    echo "Creating GCS bucket..."
    retry_with_backoff gsutil mb -p "$ORG_ID" -c "STANDARD" -l "$REGION" "gs://$STATE_BUCKET"
    echo -e "${GREEN}✓ Bucket created: gs://$STATE_BUCKET${NC}"
fi

# Enable versioning (so we can recover old states)
echo "Enabling versioning..."
retry_with_backoff gsutil versioning set on "gs://$STATE_BUCKET"
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable uniform bucket-level access (security best practice)
echo "Configuring uniform bucket-level access..."
retry_with_backoff gsutil uniformbucketlevelaccess set on "gs://$STATE_BUCKET"
echo -e "${GREEN}✓ Uniform bucket-level access enabled${NC}"

# Block public access (security)
echo "Blocking all public access..."
retry_with_backoff gsutil iam ch group:allUsers:legacyObjectReader "gs://$STATE_BUCKET" >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Public access blocked${NC}"

echo ""

################################################################################
# STEP 4: CREATE LOCAL TERRAFORM CONFIGURATION
################################################################################
echo -e "${YELLOW}[STEP 4/5] Creating Terraform configuration files...${NC}"

# Create locals.tf in each phase directory for consistent values
create_locals_tf() {
    local phase_dir=$1
    
    cat > "$phase_dir/locals.tf" << 'EOF'
# Layman's Explanation: This file stores "remembered values" that all the
# Terraform files use. Think of it like a shared notepad.
# It reads config.yaml and converts it into Terraform variables.

locals {
    config = yamldecode(file("${path.module}/../config.yaml"))

    org_id          = local.config.organization_id
    billing_account = local.config.billing_account
    default_region  = local.config.default_region

    global_modules  = try(local.config.global_modules, {})
    advanced_modules = try(local.config.advanced_modules, {})
    spokes          = try(local.config.spokes, [])

    has_gcve_foundation = anytrue([
        for spoke in local.spokes :
        try(spoke.workload_foundations.enable_gcve_networking, false)
    ])

    has_gke_multicloud_foundation = anytrue([
        for spoke in local.spokes :
        try(spoke.workload_foundations.enable_gke_multi_cloud, false)
    ])

    has_migration_foundation = anytrue([
        for spoke in local.spokes :
        try(spoke.workload_foundations.enable_migration_factory, false)
    ])

    labels = {
        "managed-by" = "terraform"
        "finops"     = "enabled"
        "framework"  = "gcp-architecture-framework-2026"
    }
}
EOF
    
    echo -e "${GREEN}✓ Created $phase_dir/locals.tf${NC}"
}

# Create directories if they don't exist
for phase in 0-Bootstrap 1-Resman 2-Networking 3-Projects; do
    mkdir -p "$phase"
    create_locals_tf "$phase"
done

echo ""

################################################################################
# STEP 5: CREATE TERRAFORM BACKEND CONFIGURATION
################################################################################
echo -e "${YELLOW}[STEP 5/5] Creating Terraform backend configuration...${NC}"

# Create backend-config.hcl for each phase
create_backend_config() {
    local phase_num=$1
    local phase_name=$2
    
    cat > "$phase_num-$phase_name/backend-config.hcl" << EOF
# Terraform Remote State Backend Configuration
# This tells Terraform to store state in the GCS bucket we just created

bucket           = "$STATE_BUCKET"
prefix           = "terraform/state/$phase_num-$phase_name"
skip_credentials_validation = false
skip_bucket_versioning = true
skip_region_update = true
skip_metadata_api_check = true
EOF
    
    echo -e "${GREEN}✓ Created $phase_num-$phase_name/backend-config.hcl${NC}"
}

create_backend_config "0" "Bootstrap"
create_backend_config "1" "Resman"
create_backend_config "2" "Networking"
create_backend_config "3" "Projects"

echo ""

################################################################################
# SUMMARY
################################################################################
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Bootstrap complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}What was created:${NC}"
echo "  • Remote state bucket: gs://$STATE_BUCKET"
echo "  • Versioning + Locking enabled"
echo "  • Public access blocked"
echo "  • Backend config files created in each phase"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. ${GREEN}cd 0-Bootstrap${NC}"
echo "2. ${GREEN}terraform init -backend-config=backend-config.hcl${NC}"
echo "3. ${GREEN}terraform apply${NC}"
echo "4. Repeat for phases 1, 2, and 3"
echo ""
echo -e "${YELLOW}To see bucket details:${NC}"
echo "  gsutil ls -L gs://$STATE_BUCKET"
echo ""
echo -e "${BLUE}For detailed instructions, see: START_HERE.md${NC}"
echo ""
