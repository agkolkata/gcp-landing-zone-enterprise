#!/bin/bash

################################################################################
# GCP Landing Zone - Dependency Checker & Auto-Installer
# 
# PURPOSE (Layman's Explanation):
# This script is like a "pre-flight checklist" for an airplane. It checks if
# you have all the tools you need (gcloud, terraform, git, tfsec) and
# automatically installs them if you don't. You only run this once.
#
# COST IMPACT: $0 (just installs software, doesn't create cloud resources)
#
# WHAT IT DOES:
# 1. Checks if you have gcloud (Google Cloud control center)
# 2. Checks if you have terraform (Infrastructure-as-Code tool)
# 3. Checks if you have tfsec (Security scanner)
# 4. Checks if you have git (version control)
# 5. If anything is missing, installs it automatically
# 6. Prints what version you have
#
# HOW TO RUN:
# ./check_and_install.sh
#
################################################################################

set -e  # Exit on any error

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)
IS_WINDOWS=false
case "$OS" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        IS_WINDOWS=true
        ;;
esac

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GCP Landing Zone - Dependency Checker & Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Detected OS: ${OS} (${ARCH})${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print success
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info
info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# CHECK 1: GCLOUD
################################################################################
echo -e "${YELLOW}[1/3] Checking Google Cloud CLI (gcloud)...${NC}"

if command_exists gcloud; then
    GCLOUD_VERSION=$(gcloud --version | head -n 1)
    success "gcloud is installed: $GCLOUD_VERSION"
else
    error "gcloud is NOT installed. Installing now..."
    
    if [ "$OS" == "Darwin" ]; then
        # macOS
        info "Installing gcloud for macOS..."
        retry_with_backoff curl https://sdk.cloud.google.com | bash
        exec -l $SHELL
    elif [ "$OS" == "Linux" ]; then
        # Linux (including WSL)
        info "Installing gcloud for Linux..."
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null 2>&1
        retry_with_backoff curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - >/dev/null 2>&1
        retry_with_backoff sudo apt-get update >/dev/null 2>&1
        retry_with_backoff sudo apt-get install -y google-cloud-cli >/dev/null 2>&1
        success "gcloud installed successfully"
    elif [ "$IS_WINDOWS" == "true" ]; then
        info "Installing gcloud for Windows via winget..."
        if command_exists winget; then
            retry_with_backoff winget install --id Google.CloudSDK -e --accept-source-agreements --accept-package-agreements >/dev/null 2>&1
            success "gcloud installed successfully"
        else
            error "winget not found"
            info "Install gcloud manually: https://cloud.google.com/sdk/docs/install"
            exit 1
        fi
    else
        error "Unsupported OS for automatic gcloud installation: $OS"
        info "Please install gcloud manually: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
fi

################################################################################
# CHECK 2: TERRAFORM
################################################################################
echo ""
echo -e "${YELLOW}[2/3] Checking Terraform...${NC}"

if command_exists terraform; then
    TF_VERSION=$(terraform -version | head -n 1)
    
    # Check if version is 1.5 or higher
    TF_VERSION_NUM=$(terraform version | grep "^Terraform v" | sed 's/Terraform v\([0-9]*\)\.\([0-9]*\).*/\1.\2/')
    TF_MAJOR=$(echo $TF_VERSION_NUM | cut -d. -f1)
    TF_MINOR=$(echo $TF_VERSION_NUM | cut -d. -f2)
    
    if [ "$TF_MAJOR" -gt 1 ] || ([ "$TF_MAJOR" -eq 1 ] && [ "$TF_MINOR" -ge 5 ]); then
        success "$TF_VERSION (version 1.5+ requirement met)"
    else
        error "$TF_VERSION is too old (need 1.5+). Updating..."
        retry_with_backoff curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - >/dev/null 2>&1
        retry_with_backoff sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" >/dev/null 2>&1
        retry_with_backoff sudo apt-get update >/dev/null 2>&1
        retry_with_backoff sudo apt-get install -y terraform >/dev/null 2>&1
        success "Terraform updated successfully"
    fi
else
    error "Terraform is NOT installed. Installing now..."
    
    if [ "$OS" == "Darwin" ]; then
        # macOS
        info "Installing Terraform for macOS..."
        brew tap hashicorp/tap >/dev/null 2>&1
        brew install hashicorp/tap/terraform >/dev/null 2>&1
        success "Terraform installed successfully"
    elif [ "$OS" == "Linux" ]; then
        # Linux (including WSL)
        info "Installing Terraform for Linux..."
        retry_with_backoff curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - >/dev/null 2>&1
        retry_with_backoff sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" >/dev/null 2>&1
        retry_with_backoff sudo apt-get update >/dev/null 2>&1
        retry_with_backoff sudo apt-get install -y terraform >/dev/null 2>&1
        success "Terraform installed successfully"
    elif [ "$IS_WINDOWS" == "true" ]; then
        info "Installing Terraform for Windows via winget..."
        if command_exists winget; then
            retry_with_backoff winget install --id Hashicorp.Terraform -e --accept-source-agreements --accept-package-agreements >/dev/null 2>&1
            success "Terraform installed successfully"
        else
            error "winget not found"
            info "Please install Terraform manually: https://www.terraform.io/downloads.html"
            exit 1
        fi
    else
        error "Unsupported OS for automatic Terraform installation: $OS"
        info "Please install Terraform manually: https://www.terraform.io/downloads.html"
        exit 1
    fi
fi

################################################################################
# CHECK 3: TFSEC (Security Scanner)
################################################################################
echo ""
echo -e "${YELLOW}[3/4] Checking tfsec (Terraform security scanner)...${NC}"

if command_exists tfsec; then
    TFSEC_VERSION=$(tfsec --version 2>&1 | head -n 1 || echo "unknown")
    success "tfsec is installed: $TFSEC_VERSION"
else
    error "tfsec is NOT installed. Installing now..."
    
    if [ "$OS" == "Darwin" ]; then
        # macOS
        info "Installing tfsec for macOS..."
        brew install tfsec >/dev/null 2>&1
        success "tfsec installed successfully"
    elif [ "$OS" == "Linux" ]; then
        # Linux (including WSL)
        info "Installing tfsec for Linux..."
        retry_with_backoff curl -L https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64 -o /tmp/tfsec >/dev/null 2>&1
        chmod +x /tmp/tfsec
        sudo mv /tmp/tfsec /usr/local/bin/tfsec
        success "tfsec installed successfully"
    elif [ "$IS_WINDOWS" == "true" ]; then
        info "Installing tfsec for Windows via winget..."
        if command_exists winget; then
            retry_with_backoff winget install --id Aquasecurity.tfsec -e --accept-source-agreements --accept-package-agreements >/dev/null 2>&1
            success "tfsec installed successfully"
        else
            error "winget not found"
            info "Please install tfsec manually: https://github.com/aquasecurity/tfsec"
            exit 1
        fi
    else
        error "Unsupported OS for automatic tfsec installation: $OS"
        info "Please install tfsec manually: https://github.com/aquasecurity/tfsec"
        exit 1
    fi
fi

################################################################################
# CHECK 4: GIT
################################################################################
echo ""
echo -e "${YELLOW}[4/4] Checking Git...${NC}"

if command_exists git; then
    GIT_VERSION=$(git --version)
    success "$GIT_VERSION"
else
    error "Git is NOT installed. Installing now..."
    
    if [ "$OS" == "Darwin" ]; then
        # macOS
        info "Installing Git for macOS..."
        brew install git >/dev/null 2>&1
        success "Git installed successfully"
    elif [ "$OS" == "Linux" ]; then
        # Linux (including WSL)
        info "Installing Git for Linux..."
        retry_with_backoff sudo apt-get update >/dev/null 2>&1
        retry_with_backoff sudo apt-get install -y git >/dev/null 2>&1
        success "Git installed successfully"
    elif [ "$IS_WINDOWS" == "true" ]; then
        info "Installing Git for Windows via winget..."
        if command_exists winget; then
            retry_with_backoff winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements >/dev/null 2>&1
            success "Git installed successfully"
        else
            error "winget not found"
            info "Please install Git manually: https://git-scm.com/download/win"
            exit 1
        fi
    else
        error "Unsupported OS for automatic Git installation: $OS"
        info "Please install Git manually: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
        exit 1
    fi
fi

################################################################################
# SUMMARY
################################################################################
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All dependencies are ready!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Tools installed:${NC}"
echo "  ✓ gcloud (Google Cloud CLI)"
echo "  ✓ terraform (Infrastructure as Code)"
echo "  ✓ tfsec (Security scanner - Shift-Left)"
echo "  ✓ git (Version control)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit config.yaml with your Organization ID and Billing Account ID"
echo "2. Run: ${GREEN}./bootstrap.sh${NC}"
echo "3. Run: ${GREEN}./plan_and_scan.sh${NC} (preview + security scan)"
echo "4. Then run the Terraform phases (0-Bootstrap, 1-Resman, 2-Networking, 3-Projects)"
echo ""
echo -e "${BLUE}For detailed instructions, see: START_HERE.md${NC}"
echo ""
