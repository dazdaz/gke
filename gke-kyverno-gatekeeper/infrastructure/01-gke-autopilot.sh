#!/bin/bash

# GKE Autopilot Cluster Setup Script
# This script creates a GKE Autopilot cluster for the Kyverno vs Gatekeeper demo

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Override these with environment variables if needed
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-policy-demo-cluster}"
NETWORK="${NETWORK:-policy-demo-network}"
SUBNETWORK="${SUBNETWORK:-policy-demo-subnet}"

# Function to print colored output
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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if PROJECT_ID is set
    if [[ -z "$PROJECT_ID" ]]; then
        # Try to get the current project
        echo "Running: gcloud config get-value project"
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        if [[ -z "$PROJECT_ID" ]]; then
            print_error "PROJECT_ID is not set. Please set it with: export PROJECT_ID=your-project-id"
            exit 1
        fi
        print_warning "Using current gcloud project: $PROJECT_ID"
    fi
    
    print_success "Prerequisites check passed"
}

# Function to enable required APIs
enable_apis() {
    print_info "Enabling required Google Cloud APIs..."
    
    echo "Running: gcloud services enable container.googleapis.com --project=$PROJECT_ID"
    gcloud services enable container.googleapis.com --project="$PROJECT_ID"
    echo "Running: gcloud services enable compute.googleapis.com --project=$PROJECT_ID"
    gcloud services enable compute.googleapis.com --project="$PROJECT_ID"
    
    print_success "APIs enabled successfully"
}

# Function to create VPC network and subnet
create_network() {
    print_info "Setting up VPC network..."
    
    # Check if network already exists
    echo "Running: gcloud compute networks describe $NETWORK --project=$PROJECT_ID"
    if gcloud compute networks describe "$NETWORK" --project="$PROJECT_ID" &> /dev/null; then
        print_warning "Network $NETWORK already exists. Checking subnet..."
    else
        print_info "Creating VPC network: $NETWORK..."
        echo "Running: gcloud compute networks create $NETWORK --project=$PROJECT_ID --subnet-mode=custom --bgp-routing-mode=regional"
        gcloud compute networks create "$NETWORK" \
            --project="$PROJECT_ID" \
            --subnet-mode=custom \
            --bgp-routing-mode=regional
        print_success "Network $NETWORK created"
    fi
    
    # Check if subnet already exists
    echo "Running: gcloud compute networks subnets describe $SUBNETWORK --region=$REGION --project=$PROJECT_ID"
    if gcloud compute networks subnets describe "$SUBNETWORK" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        print_warning "Subnet $SUBNETWORK already exists. Skipping creation."
    else
        print_info "Creating subnet: $SUBNETWORK in $REGION..."
        echo "Running: gcloud compute networks subnets create $SUBNETWORK --project=$PROJECT_ID --network=$NETWORK --region=$REGION --range=10.0.0.0/20 --secondary-range=pods=10.4.0.0/14,services=10.8.0.0/20"
        gcloud compute networks subnets create "$SUBNETWORK" \
            --project="$PROJECT_ID" \
            --network="$NETWORK" \
            --region="$REGION" \
            --range="10.0.0.0/20" \
            --secondary-range="pods=10.4.0.0/14,services=10.8.0.0/20"
        print_success "Subnet $SUBNETWORK created"
    fi
}

# Function to create the GKE Autopilot cluster
create_cluster() {
    print_info "Creating GKE Autopilot cluster: $CLUSTER_NAME in $REGION..."
    
    # Check if cluster already exists
    echo "Running: gcloud container clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID"
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME already exists. Skipping creation."
        return 0
    fi
    
    # Create the Autopilot cluster
    echo "Running: gcloud container clusters create-auto $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID --network=$NETWORK --subnetwork=$SUBNETWORK --release-channel=regular --enable-master-authorized-networks --master-authorized-networks=0.0.0.0/0 --async"
    gcloud container clusters create-auto "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --network="$NETWORK" \
        --subnetwork="$SUBNETWORK" \
        --release-channel=regular \
        --enable-master-authorized-networks \
        --master-authorized-networks="0.0.0.0/0" \
        --async
    
    print_info "Cluster creation initiated. Waiting for cluster to be ready..."
    
    # Wait for cluster to be ready
    echo "Running: gcloud container clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID"
    gcloud container clusters describe "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(status)" \
        2>/dev/null | grep -q "RUNNING" || \
    gcloud container operations list \
        --filter="TYPE=CREATE_CLUSTER AND targetLink~$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(name)" | \
    xargs -I {} gcloud container operations wait {} --region="$REGION" --project="$PROJECT_ID"
    
    print_success "Cluster $CLUSTER_NAME created successfully"
}

# Function to configure kubectl
configure_kubectl() {
    print_info "Configuring kubectl to connect to the cluster..."
    
    echo "Running: gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID"
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl configured successfully"
        kubectl cluster-info
    else
        print_error "Failed to connect to cluster"
        exit 1
    fi
}

# Function to create demo namespaces
create_namespaces() {
    print_info "Creating demo namespaces..."
    
    # Namespaces to create
    local namespaces=("kyverno-demo" "gatekeeper-demo" "apps" "gateway-infra")
    
    for ns in "${namespaces[@]}"; do
        # Check if namespace exists and is terminating
        if kubectl get namespace "$ns" &> /dev/null; then
            phase=$(kubectl get namespace "$ns" -o jsonpath='{.status.phase}')
            if [ "$phase" == "Terminating" ]; then
                print_warning "Namespace $ns is currently terminating. Forcing deletion by stripping finalizers..."
                
                # Forcefully remove finalizers to unblock deletion
                # This fixes the deadlock where a namespace waits for a deleted policy engine
                kubectl get namespace "$ns" -o json | \
                tr -d "\n" | sed "s/\"finalizers\": \[[^]]*\]/\"finalizers\": []/" | \
                kubectl replace --raw /api/v1/namespaces/$ns/finalize -f - &> /dev/null || true
                
                # Wait briefly for the API server to process the deletion
                print_info "Waiting for $ns to be removed..."
                if ! kubectl wait --for=delete namespace/"$ns" --timeout=30s; then
                    print_error "Failed to force delete namespace $ns. Please check manually."
                    exit 1
                fi
                print_success "Namespace $ns force-deleted."
            fi
        fi
        
        # Create the namespace
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done
    
    # Label namespaces for easy identification
    kubectl label namespace apps app.kubernetes.io/part-of=policy-demo --overwrite
    kubectl label namespace kyverno-demo app.kubernetes.io/part-of=policy-demo --overwrite
    kubectl label namespace gatekeeper-demo app.kubernetes.io/part-of=policy-demo --overwrite
    kubectl label namespace gateway-infra app.kubernetes.io/part-of=policy-demo --overwrite
    
    print_success "Demo namespaces created"
}

# Main function
main() {
    echo ""
    echo "=============================================="
    echo "  GKE Autopilot Cluster Setup"
    echo "  Kyverno vs Gatekeeper Demo"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    enable_apis
    create_network
    create_cluster
    configure_kubectl
    create_namespaces
    
    echo ""
    echo "=============================================="
    print_success "Setup complete!"
    echo "=============================================="
    echo ""
    echo "Cluster Details:"
    echo "  - Name: $CLUSTER_NAME"
    echo "  - Region: $REGION"
    echo "  - Project: $PROJECT_ID"
    echo ""
    echo "Next steps (use make commands):"
    echo "  1. make apply-gateway      - Install Gateway API resources"
    echo "  2. make install-kyverno    - Install Kyverno policy engine"
    echo "  3. make install-gatekeeper - Install Gatekeeper/OPA policy engine"
    echo ""
    echo "Or run everything at once:"
    echo "  make quick-start           - Install both engines + apply policies + deploy app"
    echo ""
}

# Run main function
main "$@"