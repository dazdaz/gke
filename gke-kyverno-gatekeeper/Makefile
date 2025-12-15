# Makefile for Kyverno vs Gatekeeper Demo
# Simplifies common operations

.PHONY: help gke-setup gkesetup install-kyverno install-gatekeeper apply-policies test-kyverno test-gatekeeper demo cleanup full-cleanup delete-cluster create-tls-certs check-access

# Default target
help:
	@echo "Kyverno vs Gatekeeper Demo"
	@echo ""
	@echo "Both Kyverno and Gatekeeper can be installed in the same cluster."
	@echo "They operate independently and do not conflict with each other."
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  Infrastructure:"
	@echo "    gke-setup          - Create GKE Autopilot cluster and setup namespaces"
	@echo "    apply-gateway      - Apply Gateway API resources"
	@echo "    delete-cluster     - Delete GKE cluster and VPC network (DESTRUCTIVE)"
	@echo ""
	@echo "  Policy Engines (can install one or both):"
	@echo "    install-kyverno    - Install Kyverno policy engine"
	@echo "    install-gatekeeper - Install Gatekeeper/OPA policy engine"
	@echo "    quick-start        - Install BOTH engines + apply all policies + deploy app"
	@echo ""
	@echo "  Policies:"
	@echo "    apply-policies     - Apply all policies (both engines)"
	@echo "    apply-kyverno-policies    - Apply Kyverno policies only"
	@echo "    apply-gatekeeper-policies - Apply Gatekeeper policies only"
	@echo ""
	@echo "  Testing:"
	@echo "    test-kyverno       - Run Kyverno policy tests"
	@echo "    test-gatekeeper    - Run Gatekeeper policy tests"
	@echo "    demo               - Run the complete demo"
	@echo "    status             - Show current policy and resource status"
	@echo ""
	@echo "  Applications:"
	@echo "    deploy-app         - Deploy compliant sample application"
	@echo ""
	@echo "  Cleanup:"
	@echo "    cleanup            - Remove demo resources (keeps cluster running)"
	@echo "    full-cleanup       - Remove all resources including policy engines (keeps cluster)"
	@echo ""

# Variables
KYVERNO_VERSION ?= v1.13.2
GATEKEEPER_VERSION ?= v3.18.0
PROJECT_ID ?= $(shell gcloud config get-value project)
REGION ?= us-central1
CLUSTER_NAME ?= policy-demo-cluster

# Setup GKE cluster
gke-setup:
	@echo "==> Setting up GKE Autopilot cluster..."
	@echo "==> Running: chmod +x infrastructure/01-gke-autopilot.sh"
	chmod +x infrastructure/01-gke-autopilot.sh
	@echo "==> Running: PROJECT_ID=$(PROJECT_ID) REGION=$(REGION) CLUSTER_NAME=$(CLUSTER_NAME) ./infrastructure/01-gke-autopilot.sh"
	PROJECT_ID=$(PROJECT_ID) REGION=$(REGION) CLUSTER_NAME=$(CLUSTER_NAME) ./infrastructure/01-gke-autopilot.sh
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ GKE cluster setup complete!"
	@echo ""
	@echo "  Next step: make quick-start"
	@echo "      (or make install-kyverno / make install-gatekeeper individually)"
	@echo "──────────────────────────────────────────────────────────────────"

# Alias for backward compatibility
gkesetup: gke-setup

# Install Kyverno
install-kyverno:
	@echo "==> Installing Kyverno $(KYVERNO_VERSION)..."
	@echo "==> Running: kubectl apply --server-side --force-conflicts -f https://github.com/kyverno/kyverno/releases/download/$(KYVERNO_VERSION)/install.yaml"
	kubectl apply --server-side --force-conflicts -f https://github.com/kyverno/kyverno/releases/download/$(KYVERNO_VERSION)/install.yaml
	@echo "==> Waiting for Kyverno to be ready..."
	@echo "==> Running: kubectl wait --for=condition=available --timeout=300s deployment/kyverno-admission-controller -n kyverno"
	kubectl wait --for=condition=available --timeout=300s deployment/kyverno-admission-controller -n kyverno || true
	@echo "==> Running: kubectl get pods -n kyverno"
	kubectl get pods -n kyverno
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Kyverno installation complete!"
	@echo ""
	@echo "  Next step: make apply-kyverno-policies"
	@echo "      (or make install-gatekeeper to install both engines)"
	@echo "──────────────────────────────────────────────────────────────────"

# Install Gatekeeper
install-gatekeeper:
	@echo "==> Installing Gatekeeper $(GATEKEEPER_VERSION)..."
	@echo "==> Downloading and patching Gatekeeper manifest for GKE Autopilot compatibility..."
	@curl -sL https://raw.githubusercontent.com/open-policy-agent/gatekeeper/$(GATEKEEPER_VERSION)/deploy/gatekeeper.yaml -o gatekeeper.yaml
	@# Patch webhook to be safer for Autopilot (remove wildcard match or use specific scopes if needed)
	@# For GKE Autopilot, we simply apply it and ignore the specific webhook error if it persists,
	@# OR better: filter out the wildcard rule.
	@# However, standard practice is just to apply --server-side which might handle it better, or ignore the error.
	@# Let's try applying with --server-side first, as it often resolves ownership issues.
	@echo "==> Running: kubectl apply --server-side -f gatekeeper.yaml"
	-kubectl apply --server-side -f gatekeeper.yaml || echo "Warning: Some components failed to apply. This is expected on GKE Autopilot for wildcard webhooks."
	@rm gatekeeper.yaml
	@echo "==> Waiting for Gatekeeper to be ready..."
	@echo "==> Running: kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system"
	kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system || true
	@echo "==> Running: kubectl get pods -n gatekeeper-system"
	kubectl get pods -n gatekeeper-system
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Gatekeeper installation complete!"
	@echo ""
	@echo "  Next step: make apply-gatekeeper-policies"
	@echo "      (or make install-kyverno to install both engines)"
	@echo "──────────────────────────────────────────────────────────────────"

# Create TLS certificates for gateways
create-tls-certs:
	@echo "==> Creating TLS certificates for gateways..."
	@echo "==> Ensuring namespaces exist..."
	kubectl create namespace gateway-infra --dry-run=client -o yaml | kubectl apply -f -
	kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
	@echo "==> Generating self-signed certificates..."
	@mkdir -p .tls-tmp
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout .tls-tmp/tls.key -out .tls-tmp/tls.crt \
		-subj "/CN=*.example.com" -addext "subjectAltName=DNS:*.example.com,DNS:*.apps.example.com" 2>/dev/null
	@echo "==> Creating TLS secret in gateway-infra namespace..."
	kubectl create secret tls demo-tls-secret \
		--cert=.tls-tmp/tls.crt --key=.tls-tmp/tls.key \
		-n gateway-infra --dry-run=client -o yaml | kubectl apply -f -
	@echo "==> Creating TLS secret in apps namespace..."
	kubectl create secret tls apps-tls-secret \
		--cert=.tls-tmp/tls.crt --key=.tls-tmp/tls.key \
		-n apps --dry-run=client -o yaml | kubectl apply -f -
	@rm -rf .tls-tmp
	@echo "==> TLS certificates created successfully"

# Apply Gateway API resources
apply-gateway: create-tls-certs
	@echo "==> Applying Gateway API resources..."
	@echo "==> Running: kubectl apply -f infrastructure/02-gateway-api.yaml"
	kubectl apply -f infrastructure/02-gateway-api.yaml
	@echo "==> Running: kubectl apply -f apps/gateway/gateway.yaml"
	kubectl apply -f apps/gateway/gateway.yaml
	@echo "==> Running: kubectl apply -f apps/gateway/httproutes.yaml"
	kubectl apply -f apps/gateway/httproutes.yaml
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Gateway API resources applied!"
	@echo ""
	@echo "  Next step: make deploy-app"
	@echo "──────────────────────────────────────────────────────────────────"

# Apply Kyverno policies
apply-kyverno-policies:
	@echo "==> Applying Kyverno policies..."
	@echo "==> Running: kubectl apply -f kyverno/policies/"
	kubectl apply -f kyverno/policies/
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Kyverno policies applied!"
	@echo ""
	@echo "  Next step: make test-kyverno"
	@echo "──────────────────────────────────────────────────────────────────"

# Apply Gatekeeper policies
apply-gatekeeper-policies:
	@echo "==> Applying Gatekeeper templates..."
	@echo "==> Running: kubectl apply -f gatekeeper/templates/"
	kubectl apply -f gatekeeper/templates/
	@echo "==> Waiting 5 seconds for templates to be ready..."
	sleep 5
	@echo "==> Applying Gatekeeper constraints..."
	@echo "==> Running: kubectl apply -f gatekeeper/constraints/"
	kubectl apply -f gatekeeper/constraints/
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Gatekeeper policies applied!"
	@echo ""
	@echo "  Next step: make test-gatekeeper"
	@echo "──────────────────────────────────────────────────────────────────"

# Apply all policies
apply-policies: apply-kyverno-policies apply-gatekeeper-policies
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ All policies applied!"
	@echo ""
	@echo "  Next step: make apply-gateway"
	@echo "      (or make test-kyverno / make test-gatekeeper to test)"
	@echo "──────────────────────────────────────────────────────────────────"

# Test Kyverno
test-kyverno:
	@echo "==> Running Kyverno tests..."
	@echo "==> Running: chmod +x demo/test-kyverno.sh && ./demo/test-kyverno.sh"
	chmod +x demo/test-kyverno.sh
	./demo/test-kyverno.sh
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Kyverno tests complete!"
	@echo ""
	@echo "  Next step: make test-gatekeeper"
	@echo "      (or make demo for full demo, or make status to view resources)"
	@echo "──────────────────────────────────────────────────────────────────"

# Test Gatekeeper
test-gatekeeper:
	@echo "==> Running Gatekeeper tests..."
	@echo "==> Running: chmod +x demo/test-gatekeeper.sh && ./demo/test-gatekeeper.sh"
	chmod +x demo/test-gatekeeper.sh
	./demo/test-gatekeeper.sh
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Gatekeeper tests complete!"
	@echo ""
	@echo "  Next step: make test-kyverno"
	@echo "      (or make demo for full demo, or make status to view resources)"
	@echo "──────────────────────────────────────────────────────────────────"

# Deploy compliant application
deploy-app:
	@echo "==> Deploying compliant application..."
	@echo "==> Running: kubectl apply -f apps/compliant-app/deployment.yaml"
	kubectl apply -f apps/compliant-app/deployment.yaml
	@echo "==> Running: kubectl get pods -n apps"
	kubectl get pods -n apps
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Application deployed!"
	@echo ""
	@echo "  Next step: make test-kyverno"
	@echo "      (or make test-gatekeeper, or make demo for full demo)"
	@echo "──────────────────────────────────────────────────────────────────"

# Run complete demo
demo:
	@echo "==> Running complete demo..."
	@echo "==> Running: chmod +x demo/run-demo.sh && ./demo/run-demo.sh"
	chmod +x demo/run-demo.sh
	./demo/run-demo.sh
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Demo complete!"
	@echo ""
	@echo "  Next step: make status"
	@echo "      (or make cleanup to remove demo resources)"
	@echo "──────────────────────────────────────────────────────────────────"

# Cleanup demo resources (keeps namespaces and policy engines)
cleanup:
	@echo "==> Cleaning up demo resources..."
	@echo "==> Removing application resources..."
	@echo "==> Running: kubectl delete deployment,service,configmap,pdb -n apps --all --wait=false"
	-kubectl delete deployment,service,configmap,pdb -n apps --all --ignore-not-found --wait=false || true
	@echo "==> Removing gateway routes..."
	@echo "==> Running: kubectl delete httproute -n apps --all --wait=false"
	-kubectl delete httproute -n apps --all --ignore-not-found --wait=false || true
	@echo "==> Running: kubectl delete httproute -n kyverno-demo --all --wait=false"
	-kubectl delete httproute -n kyverno-demo --all --ignore-not-found --wait=false || true
	@echo "==> Running: kubectl delete httproute -n gatekeeper-demo --all --wait=false"
	-kubectl delete httproute -n gatekeeper-demo --all --ignore-not-found --wait=false || true
	@echo "==> Running: kubectl delete httproute -n gateway-infra --all --wait=false"
	-kubectl delete httproute -n gateway-infra --all --ignore-not-found --wait=false || true
	@echo "==> Removing gateways..."
	@echo "==> Running: kubectl delete gateway -n apps --all --wait=false"
	-kubectl delete gateway -n apps --all --ignore-not-found --wait=false || true
	@echo "==> Running: kubectl delete gateway -n gateway-infra --all --wait=false"
	-kubectl delete gateway -n gateway-infra --all --ignore-not-found --wait=false || true
	@echo "==> Removing TLS secrets..."
	@echo "==> Running: kubectl delete secret demo-tls-secret -n gateway-infra --wait=false"
	-kubectl delete secret demo-tls-secret -n gateway-infra --ignore-not-found --wait=false || true
	@echo "==> Running: kubectl delete secret apps-tls-secret -n apps --wait=false"
	-kubectl delete secret apps-tls-secret -n apps --ignore-not-found --wait=false || true
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Demo resources cleaned up!"
	@echo "  (Namespaces and policy engines are preserved)"
	@echo ""
	@echo "  Next step: make full-cleanup"
	@echo "      (to remove policy engines, or make deploy-app to redeploy)"
	@echo "──────────────────────────────────────────────────────────────────"

# Full cleanup including policy engines and namespaces
full-cleanup: cleanup
	@echo "==> Checking for Kyverno installation..."
	@if kubectl get namespace kyverno >/dev/null 2>&1; then \
		echo "==> Kyverno found. Removing policies..."; \
		kubectl delete clusterpolicies --all --ignore-not-found --wait=false 2>/dev/null || true; \
		echo "==> Running: kubectl delete namespace kyverno --wait=false"; \
		kubectl delete namespace kyverno --ignore-not-found --wait=false || true; \
	else \
		echo "    (Kyverno not installed - skipping)"; \
	fi
	@echo "==> Checking for Gatekeeper installation..."
	@if kubectl get namespace gatekeeper-system >/dev/null 2>&1; then \
		echo "==> Gatekeeper found. Removing constraints and templates..."; \
		kubectl delete constraints --all --ignore-not-found --wait=false 2>/dev/null || true; \
		kubectl delete constrainttemplates --all --ignore-not-found --wait=false 2>/dev/null || true; \
		echo "==> Running: kubectl delete namespace gatekeeper-system --wait=false"; \
		kubectl delete namespace gatekeeper-system --ignore-not-found --wait=false || true; \
	else \
		echo "    (Gatekeeper not installed - skipping)"; \
	fi
	@echo "==> Removing demo namespaces..."
	@echo "==> Running: kubectl delete namespace kyverno-demo gatekeeper-demo apps gateway-infra --wait=false"
	-kubectl delete namespace kyverno-demo gatekeeper-demo apps gateway-infra --ignore-not-found --wait=false || true
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Full cleanup complete!"
	@echo ""
	@echo "  Next step: make delete-cluster"
	@echo "      (to delete GKE cluster, or make quick-start to start over)"
	@echo "──────────────────────────────────────────────────────────────────"

# Delete GKE cluster and network (DESTRUCTIVE)
delete-cluster:
	@echo "=============================================="
	@echo "  WARNING: This will delete the GKE cluster"
	@echo "  and associated VPC network!"
	@echo "=============================================="
	@echo ""
	@echo "==> Deleting GKE cluster: $(CLUSTER_NAME)..."
	@echo "==> Running: gcloud container clusters delete $(CLUSTER_NAME) --region $(REGION) --project $(PROJECT_ID) --quiet"
	-gcloud container clusters delete $(CLUSTER_NAME) --region $(REGION) --project $(PROJECT_ID) --quiet
	@echo ""
	@echo "==> Deleting VPC subnet: policy-demo-subnet..."
	@echo "==> Running: gcloud compute networks subnets delete policy-demo-subnet --region $(REGION) --project $(PROJECT_ID) --quiet"
	-gcloud compute networks subnets delete policy-demo-subnet --region $(REGION) --project $(PROJECT_ID) --quiet
	@echo ""
	@echo "==> Deleting VPC network: policy-demo-network..."
	@echo "==> Running: gcloud compute networks delete policy-demo-network --project $(PROJECT_ID) --quiet"
	-gcloud compute networks delete policy-demo-network --project $(PROJECT_ID) --quiet
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Cluster and network deleted!"
	@echo ""
	@echo "  To start over: make gke-setup"
	@echo "──────────────────────────────────────────────────────────────────"

# Quick start - install both and apply policies
quick-start: install-kyverno install-gatekeeper apply-policies apply-gateway deploy-app
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  ✓ Quick start complete!"
	@echo ""
	@echo "  Next step: make test-kyverno"
	@echo "      (or make test-gatekeeper, or make demo for full demo)"
	@echo "──────────────────────────────────────────────────────────────────"

# Show policy status
status:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                   KYVERNO POLICY STATUS                          ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo "==> Running: kubectl get clusterpolicies"
	@kubectl get clusterpolicies 2>/dev/null || echo "No Kyverno policies found"
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                 GATEKEEPER POLICY STATUS                         ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo "==> Running: kubectl get constraints"
	@kubectl get constraints 2>/dev/null || echo "No Gatekeeper constraints found"
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                     GATEWAY API STATUS                           ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo "==> Running: kubectl get gateways -A"
	@kubectl get gateways -A 2>/dev/null || echo "No gateways found"
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                     APPLICATION STATUS                           ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo "==> Running: kubectl get pods -n apps"
	@kubectl get pods -n apps 2>/dev/null || echo "No pods in apps namespace"
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  To access the application:"
	@IP=$$(kubectl get gateway demo-gateway -n gateway-infra -o jsonpath='{.status.addresses[0].value}' 2>/dev/null); \
	if [ -n "$$IP" ]; then \
		echo "  curl -H \"Host: compliant-app.example.com\" http://$$IP"; \
		echo "  (or use 'make check-access')"; \
	else \
		echo "  Gateway IP not yet assigned. Wait a few minutes and run 'make status'"; \
	fi
	@echo ""
	@echo "  Available commands: make test-kyverno | make test-gatekeeper"
	@echo "                      make demo | make cleanup"
	@echo "──────────────────────────────────────────────────────────────────"

# Check access to the application
check-access:
	@echo "==> Checking access to compliant-app..."
	@IP=$$(kubectl get gateway demo-gateway -n gateway-infra -o jsonpath='{.status.addresses[0].value}' 2>/dev/null); \
	if [ -n "$$IP" ]; then \
		echo "==> Running: curl -v -H \"Host: compliant-app.example.com\" http://$$IP"; \
		curl -v -H "Host: compliant-app.example.com" http://$$IP; \
	else \
		echo "Error: Gateway IP not yet assigned."; \
	fi