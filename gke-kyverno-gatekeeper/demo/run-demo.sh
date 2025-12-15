#!/bin/bash

# Main Demo Script for Kyverno vs Gatekeeper Comparison
# This script orchestrates the complete demo workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
KYVERNO_VERSION="${KYVERNO_VERSION:-v1.11.4}"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.14.0}"

# Function to print colored output
print_header() {
    echo ""
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}${BOLD}  $1${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_demo() {
    echo -e "${YELLOW}[DEMO]${NC} $1"
}

# Function to wait for user input
wait_for_input() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local missing=()
    
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing+=("gcloud")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing[*]}"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    
    print_success "All prerequisites met"
    kubectl cluster-info | head -2
}

# Function to setup namespaces
setup_namespaces() {
    print_section "Setting up Demo Namespaces"
    
    kubectl create namespace kyverno-demo --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace gatekeeper-demo --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Namespaces created"
}

# Function to install Kyverno
install_kyverno() {
    print_section "Installing Kyverno"
    
    print_info "Installing Kyverno ${KYVERNO_VERSION}..."
    
    # Install Kyverno using official release
    kubectl apply -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"
    
    print_info "Waiting for Kyverno to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kyverno-admission-controller -n kyverno || true
    kubectl wait --for=condition=available --timeout=300s deployment/kyverno-background-controller -n kyverno || true
    
    print_success "Kyverno installed"
    
    # Show Kyverno pods
    kubectl get pods -n kyverno
}

# Function to install Gatekeeper
install_gatekeeper() {
    print_section "Installing Gatekeeper"
    
    print_info "Installing Gatekeeper ${GATEKEEPER_VERSION}..."
    
    # Install Gatekeeper using official release
    kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
    
    print_info "Waiting for Gatekeeper to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system || true
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-audit -n gatekeeper-system || true
    
    print_success "Gatekeeper installed"
    
    # Show Gatekeeper pods
    kubectl get pods -n gatekeeper-system
}

# Function to apply Kyverno policies
apply_kyverno_policies() {
    print_section "Applying Kyverno Policies"
    
    print_info "Applying Kyverno policies from ${PROJECT_DIR}/kyverno/policies/..."
    
    for policy in "${PROJECT_DIR}"/kyverno/policies/*.yaml; do
        print_info "Applying $(basename "$policy")..."
        kubectl apply -f "$policy"
    done
    
    print_success "Kyverno policies applied"
    
    # List policies
    echo ""
    print_info "Installed Kyverno ClusterPolicies:"
    kubectl get clusterpolicies
}

# Function to apply Gatekeeper policies
apply_gatekeeper_policies() {
    print_section "Applying Gatekeeper Policies"
    
    print_info "Applying Gatekeeper ConstraintTemplates..."
    for template in "${PROJECT_DIR}"/gatekeeper/templates/*.yaml; do
        print_info "Applying $(basename "$template")..."
        kubectl apply -f "$template"
    done
    
    # Wait for templates to be ready
    sleep 5
    
    print_info "Applying Gatekeeper Constraints..."
    for constraint in "${PROJECT_DIR}"/gatekeeper/constraints/*.yaml; do
        print_info "Applying $(basename "$constraint")..."
        kubectl apply -f "$constraint"
    done
    
    print_success "Gatekeeper policies applied"
    
    # List constraints
    echo ""
    print_info "Installed Gatekeeper Constraints:"
    kubectl get constraints
}

# Function to apply Gateway API resources
apply_gateway_api() {
    print_section "Applying Gateway API Resources"
    
    print_info "Applying Gateway API configuration..."
    kubectl apply -f "${PROJECT_DIR}/infrastructure/02-gateway-api.yaml"
    
    print_info "Applying application gateway..."
    kubectl apply -f "${PROJECT_DIR}/apps/gateway/gateway.yaml"
    kubectl apply -f "${PROJECT_DIR}/apps/gateway/httproutes.yaml"
    
    print_success "Gateway API resources applied"
    
    # Show gateways
    echo ""
    print_info "Installed Gateways:"
    kubectl get gateways -A
}

# Function to test compliant application
test_compliant_app() {
    print_section "Testing Compliant Application"
    
    print_demo "Deploying compliant application..."
    print_info "This application follows all policies:"
    print_info "  ✓ Has required labels"
    print_info "  ✓ Non-privileged containers"
    print_info "  ✓ Runs as non-root"
    print_info "  ✓ Has health probes"
    print_info "  ✓ Uses specific image tags"
    
    echo ""
    cat "${PROJECT_DIR}/apps/compliant-app/deployment.yaml" | head -50
    echo "..."
    echo ""
    
    if kubectl apply -f "${PROJECT_DIR}/apps/compliant-app/deployment.yaml"; then
        print_success "Compliant application deployed successfully!"
    else
        print_error "Compliant application deployment failed!"
    fi
    
    echo ""
    kubectl get pods -n apps -l app.kubernetes.io/name=compliant-app
}

# Function to test non-compliant applications
test_non_compliant_apps() {
    print_section "Testing Non-Compliant Applications"
    
    print_demo "Attempting to deploy non-compliant applications..."
    print_warning "These should be REJECTED by both Kyverno and Gatekeeper"
    
    echo ""
    
    # Test each non-compliant resource individually
    local violations=(
        "missing-labels-pod:Missing required labels"
        "privileged-pod:Privileged container"
        "privilege-escalation-pod:Allows privilege escalation"
        "root-user-pod:Runs as root"
        "no-probes-pod:Missing health probes"
        "latest-tag-pod:Uses 'latest' tag"
        "no-tag-pod:No image tag specified"
        "untrusted-registry-pod:Untrusted registry"
    )
    
    for violation in "${violations[@]}"; do
        IFS=':' read -r pod_name description <<< "$violation"
        
        echo ""
        print_demo "Testing: ${description} (${pod_name})"
        
        # Extract the specific resource from the file
        if kubectl apply -f "${PROJECT_DIR}/apps/non-compliant-app/deployment.yaml" --dry-run=server 2>&1 | grep -q "${pod_name}"; then
            print_error "Violation: ${description}"
        fi
    done
    
    echo ""
    print_demo "Attempting full non-compliant deployment..."
    
    if kubectl apply -f "${PROJECT_DIR}/apps/non-compliant-app/deployment.yaml" 2>&1; then
        print_warning "Some resources may have been created (check for policy violations above)"
    else
        print_success "Non-compliant resources were correctly rejected!"
    fi
}

# Function to show Kyverno policy reports
show_kyverno_reports() {
    print_section "Kyverno Policy Reports"
    
    print_info "Cluster Policy Reports:"
    kubectl get clusterpolicyreports -A 2>/dev/null || print_warning "No cluster policy reports found"
    
    echo ""
    print_info "Policy Reports:"
    kubectl get policyreports -A 2>/dev/null || print_warning "No policy reports found"
}

# Function to show Gatekeeper audit results
show_gatekeeper_audit() {
    print_section "Gatekeeper Audit Results"
    
    print_info "Constraint violations:"
    kubectl get constraints -o json | jq -r '.items[] | select(.status.totalViolations > 0) | "\(.metadata.name): \(.status.totalViolations) violations"' 2>/dev/null || print_warning "No violations found or jq not installed"
    
    echo ""
    print_info "Detailed violations:"
    kubectl get constraints -o json | jq -r '.items[].status.violations[]? | "  - \(.kind)/\(.name) in \(.namespace): \(.message)"' 2>/dev/null || true
}

# Function to demonstrate mutation (Kyverno only)
demonstrate_mutation() {
    print_section "Demonstrating Kyverno Mutation"
    
    print_demo "Kyverno can automatically mutate resources to add defaults"
    print_info "This is a KEY differentiator from Gatekeeper!"
    
    echo ""
    print_info "Creating a minimal pod to demonstrate mutation..."
    
    cat <<EOF | kubectl apply -f - 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: mutation-demo
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: mutation-demo
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: demo
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1000
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 10
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
EOF

    echo ""
    print_info "Checking for mutated fields..."
    sleep 2
    
    kubectl get pod mutation-demo -n kyverno-demo -o yaml 2>/dev/null | grep -A5 "labels:" || print_warning "Pod not found - may have been rejected by policies"
    
    # Cleanup
    kubectl delete pod mutation-demo -n kyverno-demo 2>/dev/null || true
}

# Function to compare side-by-side
compare_side_by_side() {
    print_section "Side-by-Side Comparison"
    
    echo ""
    echo -e "${BOLD}Policy Lines of Code Comparison:${NC}"
    echo ""
    
    local kyverno_lines=0
    local gatekeeper_lines=0
    
    for policy in "${PROJECT_DIR}"/kyverno/policies/*.yaml; do
        lines=$(wc -l < "$policy")
        kyverno_lines=$((kyverno_lines + lines))
        echo -e "  Kyverno: $(basename "$policy"): ${lines} lines"
    done
    
    echo ""
    
    for template in "${PROJECT_DIR}"/gatekeeper/templates/*.yaml; do
        lines=$(wc -l < "$template")
        gatekeeper_lines=$((gatekeeper_lines + lines))
        echo -e "  Gatekeeper Template: $(basename "$template"): ${lines} lines"
    done
    
    for constraint in "${PROJECT_DIR}"/gatekeeper/constraints/*.yaml; do
        lines=$(wc -l < "$constraint")
        gatekeeper_lines=$((gatekeeper_lines + lines))
        echo -e "  Gatekeeper Constraint: $(basename "$constraint"): ${lines} lines"
    done
    
    echo ""
    echo -e "${BOLD}Total Lines:${NC}"
    echo -e "  Kyverno: ${kyverno_lines} lines"
    echo -e "  Gatekeeper: ${gatekeeper_lines} lines"
    echo ""
    
    echo -e "${BOLD}Key Differences:${NC}"
    echo "  ┌─────────────────────┬─────────────┬─────────────┐"
    echo "  │ Feature             │ Kyverno     │ Gatekeeper  │"
    echo "  ├─────────────────────┼─────────────┼─────────────┤"
    echo "  │ Policy Language     │ YAML        │ Rego        │"
    echo "  │ Mutation            │ ✓ Native    │ ⚠ Limited   │"
    echo "  │ Generation          │ ✓ Native    │ ✗ No        │"
    echo "  │ Learning Curve      │ Low         │ High        │"
    echo "  │ Files per Policy    │ 1           │ 2           │"
    echo "  │ Image Verification  │ ✓ Built-in  │ ⚠ External  │"
    echo "  └─────────────────────┴─────────────┴─────────────┘"
}

# Function to cleanup
cleanup() {
    print_section "Cleanup"
    
    print_info "Cleaning up demo resources..."
    
    # Delete demo apps
    kubectl delete -f "${PROJECT_DIR}/apps/compliant-app/deployment.yaml" --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f "${PROJECT_DIR}/apps/non-compliant-app/deployment.yaml" --ignore-not-found=true 2>/dev/null || true
    
    # Delete Gateway API resources
    kubectl delete -f "${PROJECT_DIR}/apps/gateway/httproutes.yaml" --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f "${PROJECT_DIR}/apps/gateway/gateway.yaml" --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f "${PROJECT_DIR}/infrastructure/02-gateway-api.yaml" --ignore-not-found=true 2>/dev/null || true
    
    print_success "Demo resources cleaned up"
}

# Function to full cleanup including policy engines
full_cleanup() {
    cleanup
    
    print_section "Full Cleanup (Including Policy Engines)"
    
    read -p "Are you sure you want to uninstall Kyverno and Gatekeeper? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing Kyverno policies..."
        kubectl delete -f "${PROJECT_DIR}/kyverno/policies/" --ignore-not-found=true 2>/dev/null || true
        
        print_info "Removing Gatekeeper constraints..."
        kubectl delete -f "${PROJECT_DIR}/gatekeeper/constraints/" --ignore-not-found=true 2>/dev/null || true
        
        print_info "Removing Gatekeeper templates..."
        kubectl delete -f "${PROJECT_DIR}/gatekeeper/templates/" --ignore-not-found=true 2>/dev/null || true
        
        print_info "Uninstalling Kyverno..."
        kubectl delete -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml" --ignore-not-found=true 2>/dev/null || true
        
        print_info "Uninstalling Gatekeeper..."
        kubectl delete -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml" --ignore-not-found=true 2>/dev/null || true
        
        print_info "Deleting namespaces..."
        kubectl delete namespace kyverno-demo gatekeeper-demo apps --ignore-not-found=true 2>/dev/null || true
        
        print_success "Full cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  full          Run the complete demo (default)"
    echo "  install       Install Kyverno and Gatekeeper only"
    echo "  policies      Apply policies only"
    echo "  test          Run policy tests only"
    echo "  kyverno       Run Kyverno-specific demo"
    echo "  gatekeeper    Run Gatekeeper-specific demo"
    echo "  compare       Show side-by-side comparison"
    echo "  cleanup       Cleanup demo resources"
    echo "  full-cleanup  Full cleanup including policy engines"
    echo "  help          Show this help message"
    echo ""
}

# Main function
main() {
    local command="${1:-full}"
    
    print_header "Kyverno vs Gatekeeper Demo"
    echo "Running on GKE Autopilot with Gateway API"
    echo ""
    
    case "$command" in
        full)
            check_prerequisites
            setup_namespaces
            install_kyverno
            install_gatekeeper
            apply_gateway_api
            
            wait_for_input
            
            apply_kyverno_policies
            apply_gatekeeper_policies
            
            wait_for_input
            
            test_compliant_app
            
            wait_for_input
            
            test_non_compliant_apps
            
            wait_for_input
            
            demonstrate_mutation
            
            wait_for_input
            
            show_kyverno_reports
            show_gatekeeper_audit
            
            wait_for_input
            
            compare_side_by_side
            
            print_header "Demo Complete!"
            echo "See docs/COMPARISON.md for detailed comparison"
            ;;
        install)
            check_prerequisites
            setup_namespaces
            install_kyverno
            install_gatekeeper
            apply_gateway_api
            ;;
        policies)
            apply_kyverno_policies
            apply_gatekeeper_policies
            ;;
        test)
            test_compliant_app
            test_non_compliant_apps
            ;;
        kyverno)
            check_prerequisites
            setup_namespaces
            install_kyverno
            apply_kyverno_policies
            test_compliant_app
            demonstrate_mutation
            show_kyverno_reports
            ;;
        gatekeeper)
            check_prerequisites
            setup_namespaces
            install_gatekeeper
            apply_gatekeeper_policies
            test_compliant_app
            show_gatekeeper_audit
            ;;
        compare)
            compare_side_by_side
            ;;
        cleanup)
            cleanup
            ;;
        full-cleanup)
            full_cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"