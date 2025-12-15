# Kyverno vs Gatekeeper on GKE Autopilot with Gateway API

This demo showcases the differences between **Kyverno** and **Gatekeeper (OPA)** for Kubernetes policy enforcement on GKE Autopilot, using Gateway API for traffic management.

## 📋 TL;DR

| Aspect | Kyverno | OPA Gatekeeper |
|--------|---------|----------------|
| **Popularity** | Rising fast due to simplicity | Mature, widely adopted |
| **Policy Language** | YAML (Kubernetes native) | Rego (learning curve) |
| **Image Signing** | Cosign integration built-in | Requires external tools |
| **Scope** | Kubernetes only | Multi-platform (K8s, VMs, Cloud Run) |
| **CNCF Status** | Incubating | Graduated |
| **Management** | DIY | Managed service available (GKE/ACM) |
| **Extensibility** | Limited to K8s resources | Highly extensible |

**Key Insights:**
- Kyverno is gaining popularity due to its simplicity (competes with OPA Gatekeeper)
- Coupled with Cosign (another CNCF project), customers can sign images and attestations (competes with Binary Authorization)
- Kyverno is less extensible than OPA Gatekeeper and only works with Kubernetes (no VM or Cloud Run support)
- Some features like SLSA support with attestations are still maturing
- Kyverno can be deployed via ConfigSync with GitOps workflows
- Kyverno requires careful security consideration for enterprise-scale deployments

## 📋 Overview

Both Kyverno and Gatekeeper are Kubernetes-native policy engines that enforce policies on resources. This demo demonstrates:

- Installation and configuration of both tools
- Equivalent policies written in both frameworks
- Gateway API integration with TLS for ingress traffic management
- Real-world policy enforcement scenarios
- Image verification and supply chain security considerations

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      GKE Autopilot Cluster                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │     Kyverno     │              │    Gatekeeper   │           │
│  │    Namespace    │              │    Namespace    │           │
│  │  ┌───────────┐  │              │  ┌───────────┐  │           │
│  │  │ Policies  │  │              │  │Constraints│  │           │
│  │  │  (YAML)   │  │              │  │(Rego/YAML)│  │           │
│  │  └───────────┘  │              │  └───────────┘  │           │
│  └─────────────────┘              └─────────────────┘           │
├─────────────────────────────────────────────────────────────────┤
│                          Gateway API                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  GatewayClass   │  │ Gateway (TLS)   │  │    HTTPRoute    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                      Sample Applications                        │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │  kyverno-demo   │              │ gatekeeper-demo │           │
│  │    namespace    │              │    namespace    │           │
│  └─────────────────┘              └─────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.
├── README.md
├── Makefile                        # Quick commands for demo
├── infrastructure/
│   ├── 01-gke-autopilot.sh         # GKE Autopilot cluster creation
│   └── 02-gateway-api.yaml         # Gateway API with TLS certificates
├── kyverno/
│   ├── install/
│   │   └── kyverno-install.yaml    # Kyverno installation
│   └── policies/
│       ├── require-labels.yaml     # Require specific labels
│       ├── disallow-privileged.yaml # Block privileged containers
│       ├── require-probes.yaml     # Require health probes
│       ├── restrict-registries.yaml # Restrict container registries
│       └── mutate-defaults.yaml    # Auto-add defaults (Kyverno-only)
├── gatekeeper/
│   ├── install/
│   │   └── gatekeeper-install.yaml # Gatekeeper installation
│   ├── templates/
│   │   ├── require-labels.yaml     # ConstraintTemplate for labels
│   │   ├── disallow-privileged.yaml # ConstraintTemplate for privileged
│   │   ├── require-probes.yaml     # ConstraintTemplate for probes
│   │   └── restrict-registries.yaml # ConstraintTemplate for registries
│   └── constraints/
│       ├── require-labels.yaml     # Constraint for labels
│       ├── disallow-privileged.yaml # Constraint for privileged
│       ├── require-probes.yaml     # Constraint for probes
│       └── restrict-registries.yaml # Constraint for registries
├── apps/
│   ├── compliant-app/
│   │   └── deployment.yaml         # App that passes all policies
│   ├── non-compliant-app/
│   │   └── deployment.yaml         # App that violates policies
│   └── gateway/
│       ├── gateway.yaml            # Gateway resource with TLS
│       └── httproutes.yaml         # HTTPRoute resources
├── demo/
│   ├── run-demo.sh                 # Main demo script
│   ├── test-kyverno.sh             # Test Kyverno policies
│   └── test-gatekeeper.sh          # Test Gatekeeper policies
└── docs/
    └── COMPARISON.md               # Detailed comparison document
```

## 🚀 Quick Start

### Prerequisites

- Google Cloud SDK (`gcloud`)
- `kubectl` CLI
- A GCP project with billing enabled

### 1. Set up the GKE Autopilot Cluster

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export CLUSTER_NAME="policy-demo-cluster"

# Run the infrastructure setup
./infrastructure/01-gke-autopilot.sh
```

### 2. Install Gateway API

```bash
kubectl apply -f infrastructure/02-gateway-api.yaml
```

### 3. Install and Test Kyverno

```bash
# Install Kyverno
kubectl apply -f kyverno/install/

# Apply policies
kubectl apply -f kyverno/policies/

# Test with demo apps
./demo/test-kyverno.sh
```

### 4. Install and Test Gatekeeper

```bash
# Install Gatekeeper
kubectl apply -f gatekeeper/install/

# Apply constraint templates
kubectl apply -f gatekeeper/templates/

# Apply constraints
kubectl apply -f gatekeeper/constraints/

# Test with demo apps
./demo/test-gatekeeper.sh
```

### 5. Run the Complete Demo

```bash
# Using the demo script
./demo/run-demo.sh

# Or using make
make demo
```

## 🔍 Key Differences

| Feature | Kyverno | Gatekeeper |
|---------|---------|------------|
| **Policy Language** | YAML (native K8s) | Rego (OPA) |
| **Learning Curve** | Low | Medium-High |
| **CNCF Status** | Incubating | Graduated |
| **Mutation Support** | Native | Limited (beta) |
| **Generation** | Built-in | Not supported |
| **Validation** | Built-in | Built-in |
| **Cleanup Policies** | Built-in | Not supported |
| **Policy Exceptions** | Native ("break glass") | excludedNamespaces only |
| **Audit Mode** | Yes | Yes |
| **Image Verification** | Built-in (Cosign) | Requires extension |
| **SLSA Support** | Preview | Via Binary Authorization |
| **Scope** | Kubernetes only | Multi-platform (VMs, Cloud Run) |
| **Managed Service** | DIY | GKE/ACM Policy Controller |
| **ArgoCD Integration** | Known frictions | Works well |
| **OpenShift Support** | Known frictions | Works well |

## 🔐 Image Verification & Supply Chain Security

### Kyverno + Cosign

Kyverno integrates with Sigstore/Cosign for image verification:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "gcr.io/my-project/*"
          attestors:
            - entries:
                - keyless:
                    subject: "*@my-company.com"
                    issuer: "https://accounts.google.com"
```

### Binary Authorization (GCP Native)

For GKE environments, Binary Authorization provides:
- Managed attestation service
- Works with GKE, Anthos, and Cloud Run
- Integrates with Container Analysis API
- Supports organization policies

See [docs/COMPARISON.md](docs/COMPARISON.md) for detailed comparison.

## 🔧 CLI Tools for CI/CD

### Kyverno CLI

```bash
# Test resources against policies (shift-left)
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml

# Apply policies against a running cluster
kyverno apply /path/to/policy.yaml --cluster

# Preview mutations offline
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml -o newresource.yaml

# Run policy tests (CI pipelines)
kyverno test /path/to/test-dir/
```

### Gatekeeper CLI (gator)

```bash
# Test constraints against resources
gator test -f /path/to/constraint.yaml

# Verify template syntax
gator verify /path/to/template.yaml
```

## 👥 Customer Guidance

| Customer Situation | Recommendation |
|-------------------|----------------|
| Already knows Rego | Push for OPA Gatekeeper, emphasize managed service |
| Already using Kyverno | Explain OPA Gatekeeper flexibility, highlight managed services |
| Wants SLSA | Full supply chain workshop with Binary Authorization & Artifact Registry |
| Needs Cloud Run | OPA Gatekeeper or Binary Authorization (Kyverno doesn't support) |
| Multi-cloud | Kyverno + Cosign for multi-cloud key management |
| Simple Kubernetes-only | Kyverno for ease of adoption |

## 📚 Documentation

See [docs/COMPARISON.md](docs/COMPARISON.md) for:
- Detailed architecture diagrams
- Side-by-side policy examples
- Image verification workflows
- CI/CD integration patterns
- Performance considerations
- Use case recommendations

## 🧹 Cleanup

```bash
# Delete the cluster
gcloud container clusters delete $CLUSTER_NAME --region $REGION --quiet
```

## 📝 License

MIT License

## 🔗 Resources

### Kyverno
- [Official Documentation](https://kyverno.io/docs/)
- [Policy Library](https://kyverno.io/policies/)
- [GitHub Repository](https://github.com/kyverno/kyverno)

### Gatekeeper
- [Official Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Constraint Library](https://github.com/open-policy-agent/gatekeeper-library)
- [ACM Policy Controller](https://cloud.google.com/anthos-config-management/docs/concepts/policy-controller)

### Supply Chain Security
- [Sigstore/Cosign](https://docs.sigstore.dev/)
- [Binary Authorization](https://cloud.google.com/binary-authorization/docs)
- [SLSA Framework](https://slsa.dev/)

### Gateway API
- [Official Documentation](https://gateway-api.sigs.k8s.io/)
- [GKE Gateway Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)