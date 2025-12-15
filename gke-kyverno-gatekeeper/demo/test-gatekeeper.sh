#!/bin/bash

# Gatekeeper-specific Test Script
# Tests Gatekeeper/OPA policies with various scenarios

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
echo "Running: kubectl create namespace gatekeeper-demo --dry-run=client -o yaml | kubectl apply -f -"
kubectl create namespace gatekeeper-demo --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

print_section "Testing Gatekeeper Policies"

# Test 1: Compliant Pod
run_test "Compliant Pod with all requirements" "true" '
apiVersion: v1
kind: Pod
metadata:
  name: test-compliant
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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
  namespace: gatekeeper-demo
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

print_section "Gatekeeper Audit Report"

echo "Checking for constraint violations in the cluster..."
echo ""

echo "Constraint Status:"
echo "Running: kubectl get constraints -o custom-columns=NAME:.metadata.name,ENFORCEMENT:.spec.enforcementAction,VIOLATIONS:.status.totalViolations"
kubectl get constraints -o custom-columns=NAME:.metadata.name,ENFORCEMENT:.spec.enforcementAction,VIOLATIONS:.status.totalViolations 2>/dev/null || echo "No constraints found or unable to get status"

echo ""
echo "Detailed Violations:"

# Get violations for each constraint type
echo "Running: kubectl get constraints -o jsonpath='{range .items[*]}{.kind}{\"\n\"}{end}'"
for constraint_type in $(kubectl get constraints -o jsonpath='{range .items[*]}{.kind}{"\n"}{end}' 2>/dev/null | sort -u); do
    echo ""
    echo "--- $constraint_type ---"
    echo "Running: kubectl get \"$constraint_type\" -o json | jq ..."
    kubectl get "$constraint_type" -o json 2>/dev/null | jq -r '.items[] | select(.status.violations != null) | .status.violations[] | "  \(.kind)/\(.name) in \(.namespace // "cluster"): \(.message)"' 2>/dev/null || echo "  No violations"
done

print_section "Gatekeeper Mutation Check"

echo "Checking if Gatekeeper mutation is enabled..."
echo "Running: kubectl get assignmetadata -A"
if kubectl get assignmetadata -A &> /dev/null; then
    echo ""
    echo "AssignMetadata resources:"
    kubectl get assignmetadata -A 2>/dev/null || echo "None found"
    
    echo ""
    echo "Assign resources:"
    echo "Running: kubectl get assign -A"
    kubectl get assign -A 2>/dev/null || echo "None found"
else
    echo "Gatekeeper mutation feature may not be enabled."
    echo "Note: Unlike Kyverno, Gatekeeper mutation is a separate feature that must be enabled."
fi

print_section "Gatekeeper vs Kyverno Key Differences Demonstrated"

echo "1. POLICY LANGUAGE"
echo "   Gatekeeper uses Rego (a declarative query language)"
echo "   Example from our templates:"
echo ""
echo '   violation[{"msg": msg}] {'
echo '     provided := {label | input.review.object.metadata.labels[label]}'
echo '     required := {label | label := input.parameters.labels[_]}'
echo '     missing := required - provided'
echo '     count(missing) > 0'
echo '     msg := sprintf("Missing labels: %v", [missing])'
echo '   }'
echo ""

echo "2. TWO-STEP POLICY DEFINITION"
echo "   Gatekeeper requires:"
echo "   - ConstraintTemplate (defines Rego logic)"
echo "   - Constraint (instantiates template with parameters)"
echo ""

echo "3. MUTATION LIMITATIONS"
echo "   Gatekeeper mutation:"
echo "   - Is a separate feature (must be enabled)"
echo "   - Uses different CRDs (Assign, AssignMetadata)"
echo "   - Less intuitive than Kyverno's patchStrategicMerge"
echo ""

echo "4. NO RESOURCE GENERATION"
echo "   Gatekeeper cannot automatically create resources"
echo "   (unlike Kyverno's generate rules)"
echo ""

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