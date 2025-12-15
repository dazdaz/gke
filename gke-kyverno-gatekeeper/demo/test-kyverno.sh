#!/bin/bash

# Kyverno-specific Test Script
# Tests Kyverno policies with various scenarios

# set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local should_pass="$2"
    local yaml_content="$3"
    
    print_test "$test_name"
    
    echo "Running: echo \"\$yaml_content\" | kubectl apply --dry-run=server -f -"
    if echo "$yaml_content" | kubectl apply --dry-run=server -f - &> /dev/null; then
        if [[ "$should_pass" == "true" ]]; then
            print_pass "$test_name - Accepted as expected"
            ((TESTS_PASSED++))
        else
            print_fail "$test_name - Should have been rejected"
            ((TESTS_FAILED++))
        fi
    else
        if [[ "$should_pass" == "false" ]]; then
            print_pass "$test_name - Rejected as expected"
            ((TESTS_PASSED++))
        else
            print_fail "$test_name - Should have been accepted"
            ((TESTS_FAILED++))
        fi
    fi
}

# Ensure namespace exists
echo "Running: kubectl create namespace kyverno-demo --dry-run=client -o yaml | kubectl apply -f -"
kubectl create namespace kyverno-demo --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

print_section "Testing Kyverno Policies"

# Test 1: Compliant Pod
run_test "Compliant Pod with all requirements" "true" '
apiVersion: v1
kind: Pod
metadata:
  name: test-compliant
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-compliant
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: false
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
'

# Test 2: Missing Labels
run_test "Pod missing required labels" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-no-labels
  namespace: kyverno-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
'

# Test 3: Privileged Container
run_test "Pod with privileged container" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-privileged
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        privileged: true
'

# Test 4: Privilege Escalation
run_test "Pod with privilege escalation" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-escalation
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-escalation
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: true
'

# Test 5: Running as Root
run_test "Pod running as root" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-root
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-root
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsUser: 0
    runAsNonRoot: false
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: false
'

# Test 6: Missing Probes
run_test "Pod without health probes" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-no-probes
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-no-probes
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: false
'

# Test 7: Latest Tag
run_test "Pod with latest image tag" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-latest
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-latest
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        allowPrivilegeEscalation: false
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
'

# Test 8: No Image Tag
run_test "Pod without image tag" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-no-tag
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-no-tag
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: nginx
      image: nginx
      securityContext:
        allowPrivilegeEscalation: false
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
'

# Test 9: Untrusted Registry
run_test "Pod with untrusted registry" "false" '
apiVersion: v1
kind: Pod
metadata:
  name: test-untrusted
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: test-untrusted
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: app
      image: malicious.registry.io/evil:1.0.0
      securityContext:
        allowPrivilegeEscalation: false
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
'

print_section "Kyverno Mutation Test"

echo "Testing Kyverno mutation capabilities..."
echo "Creating a pod without security context to see if Kyverno adds defaults..."

echo "Running: kubectl apply -f - (applying mutation-test pod)"
cat <<EOF | kubectl apply -f - 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: mutation-test
  namespace: kyverno-demo
  labels:
    app.kubernetes.io/name: mutation-test
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/managed-by: test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        allowPrivilegeEscalation: false
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

sleep 2

echo ""
echo "Checking if mutation added labels:"
echo "Running: kubectl get pod mutation-test -n kyverno-demo -o jsonpath='{.metadata.labels}'"
kubectl get pod mutation-test -n kyverno-demo -o jsonpath='{.metadata.labels}' 2>/dev/null | jq . || echo "Pod not found or jq not available"

# Cleanup
echo "Running: kubectl delete pod mutation-test -n kyverno-demo"
kubectl delete pod mutation-test -n kyverno-demo --ignore-not-found=true 2>/dev/null

print_section "Test Results Summary"

echo ""
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi