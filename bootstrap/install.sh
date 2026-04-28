#!/bin/bash

###############################################################################
# Red Hat JBoss Modernization Demo - Bootstrap Installer
#
# This script installs the complete demo environment using the app-of-apps
# pattern with ArgoCD. It:
#   1. Validates prerequisites
#   2. Installs OpenShift GitOps operator
#   3. Deploys the app-of-apps ArgoCD application
#   4. Monitors installation progress
#
# Usage:
#   ./install.sh              # Install everything
#   ./install.sh --status     # Check installation status
#   ./install.sh --urls       # Display access URLs
#   ./install.sh --uninstall  # Remove all components
#   ./install.sh --help       # Show help
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITOPS_NAMESPACE="openshift-gitops"
GITOPS_OPERATOR_NAME="openshift-gitops-operator"
APP_OF_APPS_NAME="rh-jboss-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

###############################################################################
# Validation Functions
###############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check oc CLI
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install the OpenShift CLI."
        echo "Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
        exit 1
    fi
    print_success "oc CLI found: $(oc version --client -o yaml | grep gitVersion | awk '{print $2}')"

    # Check cluster connectivity
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    print_success "Connected to cluster: $(oc whoami --show-server)"
    print_info "Logged in as: $(oc whoami)"

    # Check cluster admin permissions
    if ! oc auth can-i create namespace --all-namespaces &> /dev/null; then
        print_error "Cluster admin permissions required. Current user does not have sufficient privileges."
        exit 1
    fi
    print_success "Cluster admin permissions verified"

    # Check Git repository URL is updated
    if grep -q "CHANGEME" "$REPO_ROOT/argocd/app-of-apps.yaml"; then
        print_error "Git repository URL not updated in argocd/app-of-apps.yaml"
        echo ""
        echo "Please update the repository URL:"
        echo "  1. Fork this repository to your Git provider"
        echo "  2. Update 'repoURL' in argocd/app-of-apps.yaml"
        echo "  3. Run this script again"
        echo ""
        echo "Example:"
        echo "  sed -i 's|https://github.com/CHANGEME/rh-jboss-demo|https://github.com/YOUR_USERNAME/rh-jboss-demo|g' argocd/app-of-apps.yaml"
        exit 1
    fi
    print_success "Git repository URL configured"

    echo ""
}

###############################################################################
# Installation Functions
###############################################################################

install_gitops_operator() {
    print_header "Installing OpenShift GitOps Operator"

    # Create namespace if it doesn't exist
    if ! oc get namespace $GITOPS_NAMESPACE &> /dev/null; then
        print_info "Creating namespace: $GITOPS_NAMESPACE"
        oc create namespace $GITOPS_NAMESPACE
        print_success "Namespace created"
    else
        print_info "Namespace already exists: $GITOPS_NAMESPACE"
    fi

    # Check if operator is already installed
    if oc get subscription $GITOPS_OPERATOR_NAME -n openshift-operators &> /dev/null; then
        print_info "OpenShift GitOps operator already installed"
    else
        print_info "Creating operator subscription"
        cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $GITOPS_OPERATOR_NAME
  namespace: openshift-operators
spec:
  channel: latest
  name: $GITOPS_OPERATOR_NAME
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
        print_success "Operator subscription created"
    fi

    # Wait for operator to be ready
    print_info "Waiting for GitOps operator to be ready (this may take 2-3 minutes)..."
    local timeout=300
    local elapsed=0
    while ! oc get csv -n openshift-operators | grep -q "gitops-operator.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_error "Timeout waiting for GitOps operator to be ready"
            echo "Check operator status: oc get csv -n openshift-operators | grep gitops"
            exit 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    echo ""
    print_success "GitOps operator is ready"

    # Wait for ArgoCD server to be running
    print_info "Waiting for ArgoCD server to be ready..."
    oc wait --for=condition=Ready pod \
        -l app.kubernetes.io/name=openshift-gitops-server \
        -n $GITOPS_NAMESPACE \
        --timeout=300s &> /dev/null || true

    # Give it a few more seconds to fully initialize
    sleep 10
    print_success "ArgoCD server is ready"

    echo ""
}

deploy_app_of_apps() {
    print_header "Deploying App-of-Apps"

    print_info "Applying app-of-apps ArgoCD application"
    oc apply -f "$REPO_ROOT/argocd/app-of-apps.yaml"
    print_success "App-of-apps deployed"

    print_info "ArgoCD will now automatically install all components:"
    echo "  - OpenShift Pipelines (Tekton)"
    echo "  - OpenShift DevSpaces"
    echo "  - Red Hat Developer Hub"
    echo "  - Kitchensink Demo Application"

    echo ""
    print_info "Monitor progress with:"
    echo "  ./install.sh --status"
    echo "  OR"
    echo "  watch oc get applications -n $GITOPS_NAMESPACE"

    echo ""
}

###############################################################################
# Status Functions
###############################################################################

show_status() {
    print_header "Installation Status"

    # Check if app-of-apps exists
    if ! oc get application $APP_OF_APPS_NAME -n $GITOPS_NAMESPACE &> /dev/null; then
        print_warning "App-of-apps not found. Run './install.sh' to install."
        return 1
    fi

    echo ""
    echo "ArgoCD Applications:"
    echo "-------------------"
    oc get applications -n $GITOPS_NAMESPACE -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
MESSAGE:.status.conditions[0].message 2>/dev/null || \
    oc get applications -n $GITOPS_NAMESPACE

    echo ""
    echo "Operator Status:"
    echo "---------------"
    oc get csv -A | grep -E "gitops|pipelines|devspaces|backstage" || echo "No operators found"

    echo ""
    local all_synced=true
    local apps=("openshift-pipelines" "openshift-devspaces" "developer-hub" "kitchensink")

    for app in "${apps[@]}"; do
        if oc get application $app -n $GITOPS_NAMESPACE &> /dev/null; then
            local sync_status=$(oc get application $app -n $GITOPS_NAMESPACE -o jsonpath='{.status.sync.status}')
            local health_status=$(oc get application $app -n $GITOPS_NAMESPACE -o jsonpath='{.status.health.status}')

            if [ "$sync_status" != "Synced" ] || [ "$health_status" != "Healthy" ]; then
                all_synced=false
            fi
        else
            all_synced=false
        fi
    done

    echo ""
    if $all_synced; then
        print_success "All components are synced and healthy!"
        echo ""
        print_info "Get access URLs with: ./install.sh --urls"
    else
        print_warning "Some components are still installing..."
        print_info "Run './install.sh --status' again in a few minutes"
        print_info "Or watch progress: watch oc get applications -n $GITOPS_NAMESPACE"
    fi

    echo ""
}

show_urls() {
    print_header "Access URLs"

    echo ""
    echo -e "${GREEN}ArgoCD Console:${NC}"
    local argocd_url=$(oc get route openshift-gitops-server -n $GITOPS_NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    echo "  URL: https://$argocd_url"
    if [ "$argocd_url" != "Not ready yet" ]; then
        local argocd_pass=$(oc get secret openshift-gitops-cluster -n $GITOPS_NAMESPACE -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d || echo "")
        echo "  Username: admin"
        echo "  Password: $argocd_pass"
    fi

    echo ""
    echo -e "${GREEN}Red Hat Developer Hub:${NC}"
    local devhub_url=$(oc get route backstage -n rhdh -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    echo "  URL: https://$devhub_url"

    echo ""
    echo -e "${GREEN}OpenShift DevSpaces:${NC}"
    local devspaces_url=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    echo "  URL: https://$devspaces_url"

    echo ""
    echo -e "${GREEN}Kitchensink Application:${NC}"
    local kitchensink_url=$(oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    echo "  URL: http://$kitchensink_url"

    echo ""
    echo -e "${BLUE}Kitchensink DevSpaces Workspace:${NC}"
    if [ "$devspaces_url" != "Not ready yet" ]; then
        local git_repo=$(grep "repoURL:" "$REPO_ROOT/argocd/app-of-apps.yaml" | head -1 | awk '{print $2}')
        echo "  URL: https://$devspaces_url/#$git_repo"
    else
        echo "  DevSpaces not ready yet"
    fi

    echo ""
}

###############################################################################
# Uninstall Function
###############################################################################

uninstall() {
    print_header "Uninstalling Demo Environment"

    read -p "Are you sure you want to uninstall all demo components? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Uninstall cancelled"
        exit 0
    fi

    echo ""
    print_info "Deleting app-of-apps (will cascade to all child applications)..."
    oc delete application $APP_OF_APPS_NAME -n $GITOPS_NAMESPACE --ignore-not-found=true
    print_success "App-of-apps deleted"

    # Wait for child apps to be removed
    print_info "Waiting for child applications to be removed..."
    sleep 10

    print_info "Deleting application namespaces..."
    oc delete namespace kitchensink-dev --ignore-not-found=true &
    oc delete namespace rhdh --ignore-not-found=true &
    oc delete namespace openshift-devspaces --ignore-not-found=true &
    wait
    print_success "Application namespaces deleted"

    echo ""
    read -p "Remove operators? (This may affect other applications) (yes/no): " remove_operators
    if [ "$remove_operators" == "yes" ]; then
        print_info "Removing operator subscriptions..."
        oc delete subscription openshift-gitops-operator -n openshift-operators --ignore-not-found=true
        oc delete subscription openshift-pipelines-operator-rh -n openshift-operators --ignore-not-found=true
        oc delete subscription devspaces -n openshift-operators --ignore-not-found=true
        oc delete subscription backstage-operator -n openshift-operators --ignore-not-found=true
        print_success "Operator subscriptions removed"

        print_warning "Operator CRDs and cluster-wide resources remain"
        print_info "To fully clean up, manually delete CRDs if no other applications depend on them"
    fi

    echo ""
    print_success "Uninstall complete"
    echo ""
}

###############################################################################
# Main Function
###############################################################################

show_help() {
    cat << EOF
Red Hat JBoss Modernization Demo - Bootstrap Installer

USAGE:
    ./install.sh [OPTION]

OPTIONS:
    (none)          Install the complete demo environment
    --status        Show installation status
    --urls          Display access URLs for all components
    --uninstall     Remove all demo components
    --help          Show this help message

EXAMPLES:
    # Install everything
    ./install.sh

    # Check installation progress
    ./install.sh --status

    # Get access URLs once installation completes
    ./install.sh --urls

    # Remove all demo components
    ./install.sh --uninstall

DESCRIPTION:
    This script bootstraps the Red Hat JBoss demo environment using
    the app-of-apps pattern with ArgoCD. It installs:

    - OpenShift GitOps (ArgoCD)
    - OpenShift Pipelines (Tekton)
    - OpenShift DevSpaces
    - Red Hat Developer Hub
    - Kitchensink JBoss demo application

    Installation typically takes 8-15 minutes.

PREREQUISITES:
    - OpenShift 4.12+ cluster
    - oc CLI installed
    - Cluster admin access
    - Git repository URL updated in argocd/app-of-apps.yaml

For more information, see the README.md file.
EOF
}

main() {
    case "${1:-}" in
        --status)
            show_status
            ;;
        --urls)
            show_urls
            ;;
        --uninstall)
            uninstall
            ;;
        --help|-h)
            show_help
            ;;
        "")
            print_header "Red Hat JBoss Modernization Demo - Installer"
            echo ""
            check_prerequisites
            install_gitops_operator
            deploy_app_of_apps

            print_header "Installation Started Successfully"
            echo ""
            print_success "The app-of-apps has been deployed!"
            echo ""
            print_info "ArgoCD is now installing all components automatically."
            print_info "This will take approximately 8-15 minutes."
            echo ""
            print_info "Monitor progress:"
            echo "  ./install.sh --status"
            echo ""
            print_info "Once complete, get access URLs:"
            echo "  ./install.sh --urls"
            echo ""
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
