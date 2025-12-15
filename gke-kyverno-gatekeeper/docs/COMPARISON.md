# Kyverno vs Gatekeeper: A Comprehensive Comparison

This document provides an in-depth comparison of **Kyverno** and **Gatekeeper (OPA)** for Kubernetes policy enforcement, including image verification and supply chain security considerations.

## Table of Contents

1. [TL;DR](#tldr)
2. [Overview](#overview)
3. [Architecture](#architecture)
4. [Policy Language](#policy-language)
5. [Feature Comparison](#feature-comparison)
6. [Image Verification & Supply Chain Security](#image-verification--supply-chain-security)
7. [CI/CD Integration](#cicd-integration)
8. [Policy Examples Side-by-Side](#policy-examples-side-by-side)
9. [Performance Considerations](#performance-considerations)
10. [Use Case Recommendations](#use-case-recommendations)
11. [Customer Guidance](#customer-guidance)
12. [Integration with Gateway API](#integration-with-gateway-api)

---

## TL;DR

| Aspect | [Kyverno](https://kyverno.io/) | [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) |
|--------|---------|----------------|
| **Popularity** | Rising fast due to simplicity | Mature, widely adopted |
| **Policy Language** | YAML (Kubernetes native) | Rego (learning curve) |
| **Image Signing** | Cosign integration built-in | Requires external tools |
| **Scope** | Kubernetes only | Multi-platform (K8s, VMs, Cloud Run) |
| **CNCF Status** | Incubating | Graduated |
| **Management** | DIY | Managed service available (GKE/ACM) |
| **Extensibility** | Limited to K8s resources | Highly extensible |

**Key Takeaways:**
- Kyverno is gaining popularity due to its simplicity (competes with OPA Gatekeeper)
- Coupled with Cosign (another CNCF project), customers can sign images and attestations (competes with Binary Authorization)
- Kyverno is less extensible than OPA Gatekeeper and only works with Kubernetes (no VM or Cloud Run support)
- Some features like SLSA support with attestations are still maturing
- Kyverno can be deployed via ConfigSync with GitOps workflows
- Kyverno requires careful security consideration for enterprise-scale deployments

---

## Overview

### Kyverno

**Kyverno** (Greek for "govern") is a CNCF Incubating project designed specifically for Kubernetes. It uses Kubernetes-native constructs and YAML for policy definitions.

**Key Characteristics:**
- Kubernetes-native policy management
- YAML-based (works with kustomize)
- Supports validation, mutation, generation, and cleanup
- OCI image supply chain security with Cosign
- Based on admission controller architecture
- Easy installation via Helm or kubectl

**Installation:**
```bash
# Kubectl method
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.11.4/install.yaml

# Helm method (recommended for production)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
  --set replicaCount=3
```

> **Note:** Kyverno must be deployed in its own namespace. There are known installation frictions with ArgoCD and OpenShift.

### Gatekeeper (OPA)

**Gatekeeper** is a CNCF Graduated project and the Kubernetes integration for Open Policy Agent (OPA). It uses Rego, a powerful declarative query language.

**Key Characteristics:**
- Part of the broader OPA ecosystem
- Policies written in Rego
- Highly flexible and expressive
- Reusable across different platforms (Kubernetes, VMs, Cloud Run)
- Strong in complex logic and data-driven policies
- Available as a managed service on GKE/Anthos (ACM Policy Controller)

---

## Architecture

### Kyverno Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Admission Webhooks                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │   Validating    │  │    Mutating     │  │  Generating │  │
│  │    Webhook      │  │    Webhook      │  │   Webhook   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Kyverno Controllers                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │ Admission Controller │  │ Background Controller│         │
│  └──────────────────────┘  └──────────────────────┘         │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │  Cleanup Controller  │  │  Reports Controller  │         │
│  └──────────────────────┘  └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   ClusterPolicy / Policy                    │
│                        (YAML CRDs)                          │
└─────────────────────────────────────────────────────────────┘
```

**Components:**
- **Admission Controller**: Handles validation and mutation during admission
- **Background Controller**: Processes existing resources for policy compliance
- **Cleanup Controller**: Manages resource cleanup based on policies and schedules
- **Reports Controller**: Generates policy reports

> **Note:** All mutation rules are applied first across all policies before any validation rules are applied.

### Gatekeeper Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Validating Webhook                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Gatekeeper Controller                    │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │     OPA Engine       │  │   Audit Controller   │         │
│  │       (Rego)         │  │                      │         │
│  └──────────────────────┘  └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │ ConstraintTemplate  │───▶│    Constraint       │         │
│  │    (Rego Logic)     │    │   (Parameters)      │         │
│  └─────────────────────┘    └─────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

**Components:**
- **OPA Engine**: Evaluates Rego policies
- **Audit Controller**: Periodically scans existing resources
- **ConstraintTemplate**: Defines the policy logic in Rego
- **Constraint**: Instantiates a template with specific parameters

---

## Policy Language

### Kyverno - YAML-based Policies

Kyverno uses familiar Kubernetes YAML syntax:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-for-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "label 'app.kubernetes.io/name' is required"
        pattern:
          metadata:
            labels:
              app.kubernetes.io/name: "?*"
```

**Policy Types:**
- **ClusterPolicy**: Applies to the whole cluster
- **Policy**: Applies to a specific namespace
- **PolicyException**: Grants resources the ability to bypass existing policies ("break glass" scenarios)
- **CleanupPolicy**: Removes resources based on a schedule (e.g., after deployments)

**Advantages:**
- No new language to learn
- Familiar to Kubernetes users
- Works with kustomize
- Easy to read and maintain
- IDE support with YAML schemas

**Disadvantages:**
- Less flexible for complex logic
- Limited to Kubernetes resources
- Fixed list of policy capabilities

### Gatekeeper - Rego-based Policies

Gatekeeper uses OPA's Rego language:

```yaml
# ConstraintTemplate (defines the Rego logic)
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing labels: %v", [missing])
        }
```

```yaml
# Constraint (uses the template)
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-labels
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels:
      - "app.kubernetes.io/name"
```

**Advantages:**
- Very powerful and flexible
- Supports complex logic and data transformations
- Reusable across OPA ecosystem
- Template library available
- Can be customized for any use case
- Supports VMs and other resources beyond Kubernetes

**Disadvantages:**
- Steep learning curve (Rego)
- More verbose for simple policies
- Two-step process (template + constraint)

---

## Feature Comparison

| Feature | Kyverno | OPA Gatekeeper |
|---------|---------|----------------|
| Policy Language | YAML | Rego |
| Learning Curve | Low | High |
| CNCF Status | Incubating | Graduated |
| Management | DIY | Managed (GKE/ACM available) |
| Validation | ✅ Native | ✅ Native |
| Mutation | ✅ Native | ⚠️ Limited (beta) |
| Generation | ✅ Native | ❌ Not supported |
| Cleanup Policies | ✅ Native | ❌ Not supported |
| Policy Exceptions | ✅ Native | ⚠️ excludedNamespaces only |
| Audit Mode | ✅ Yes | ✅ Yes |
| Background Scanning | ✅ Yes | ✅ Yes |
| Image Verification | ✅ Built-in (Cosign) | ⚠️ Requires extension |
| SLSA Support | ⚠️ Preview | ⚠️ Via Binary Authorization |
| Policy Reports | ✅ Native CRDs | ⚠️ Via audit results |
| Namespace Scope | ✅ ClusterPolicy & Policy | ✅ Cluster-wide only |
| External Data | ✅ ConfigMaps, APIs | ✅ OPA External Data |
| CLI Tool | ✅ kyverno CLI | ✅ gator CLI |
| Pod Security Standards | ✅ Built-in | ⚠️ Library required |
| Multi-platform | ❌ Kubernetes only | ✅ VMs, Cloud Run, etc. |
| ArgoCD Integration | ⚠️ Known frictions | ✅ Works well |
| OpenShift Support | ⚠️ Known frictions | ✅ Works well |

### GKE Platform Compatibility

| Platform | Kyverno | OPA Gatekeeper | Binary Authorization |
|----------|---------|----------------|----------------------|
| GKE Standard | ✅ Supported | ✅ Supported | ✅ Supported |
| GKE Autopilot | ✅ Supported | ✅ Supported | ✅ Supported |
| GKE Enterprise (Anthos) | ✅ Supported | ✅ Managed* | ✅ Supported |
| Cloud Run | ❌ No | ❌ No | ✅ Supported |
| Anthos on-prem | ✅ Supported | ✅ Managed* | ✅ Supported |
| Anthos multi-cloud (AWS) | ✅ Supported | ✅ Managed* | ⚠️ Limited |
| Anthos multi-cloud (Azure) | ✅ Supported | ✅ Managed* | ⚠️ Limited |

*OPA Gatekeeper is available as "Policy Controller" - a managed service via ACM

**GKE Autopilot Considerations:**

| Aspect | Kyverno | OPA Gatekeeper | Notes |
|--------|---------|----------------|-------|
| **Installation** | Helm/kubectl | Helm/kubectl or ACM | Both work on Autopilot |
| **Privileged Pods** | N/A | N/A | Autopilot blocks privileged pods by default |
| **Host Access** | N/A | N/A | Autopilot restricts hostPath, hostNetwork |
| **Node Affinity** | Automatic | Automatic | Autopilot manages node scheduling |
| **Resource Requests** | Required | Required | Autopilot enforces resource requests |
| **Managed Service** | ❌ DIY | ✅ ACM Policy Controller | ACM provides managed Gatekeeper |

**Key Notes for GKE Autopilot:**
- Both Kyverno and Gatekeeper work on GKE Autopilot without special configuration
- Autopilot already enforces many security policies by default (no privileged containers, no host access)
- Policy engines complement Autopilot's built-in security with custom organizational policies
- For managed experience on Autopilot, consider ACM Policy Controller (based on Gatekeeper)

---

## Image Verification & Supply Chain Security

### Kyverno + Cosign (CNCF Approach)

Kyverno integrates with Cosign for image signing and attestation verification:

```
┌────────────────────────────────────────────────────────────────────┐
│                         Supply Chain Flow                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Build          Package         Deploy          Runtime            │
│    │               │               │               │               │
│    ▼               ▼               ▼               ▼               │
│ ┌──────┐      ┌──────────┐   ┌──────────┐   ┌──────────────┐       │
│ │Build │      │  Scan    │   │ kubectl  │   │   Kyverno    │       │
│ │Image │──────│  Image   │───│  apply   │───│  Admission   │       │
│ └──────┘      └──────────┘   └──────────┘   │  Controller  │       │
│    │               │                        └──────────────┘       │
│    ▼               ▼                               │               │
│ ┌──────────────────────────────┐                   │               │
│ │    Sign with Cosign          │                   ▼               │
│ │  • Build attestation         │          ┌──────────────┐         │
│ │  • Vulnerability attestation │          │   Validate   │         │
│ └──────────────────────────────┘          │ Attestations │         │
│              │                            └──────────────┘         │
│              ▼                                     │               │
│       ┌────────────┐                               ▼               │
│       │  Registry  │◀──────────────────── Pull & Verify            │
│       └────────────┘                                               │
└────────────────────────────────────────────────────────────────────┘
```

**Kyverno Image Verification Policy:**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
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
            - "us-docker.pkg.dev/my-project/*"
          attestors:
            - entries:
                - keyless:
                    subject: "*@my-company.com"
                    issuer: "https://accounts.google.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

**Kyverno SLSA Attestation Verification:**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-slsa-provenance
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-slsa-provenance
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "*"
          attestations:
            - predicateType: https://slsa.dev/provenance/v0.2
              attestors:
                - entries:
                    - keyless:
                        subject: "https://github.com/slsa-framework/*"
                        issuer: "https://token.actions.githubusercontent.com"
              conditions:
                - all:
                    - key: "{{ builder.id }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*"
```

### Binary Authorization (Google Cloud Approach)

```
┌────────────────────────────────────────────────────────────────────┐
│                    Binary Authorization Flow                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Build          Package         Deploy          Runtime            │
│    │               │               │               │               │
│    ▼               ▼               ▼               ▼               │
│ ┌──────┐      ┌──────────┐   ┌──────────┐   ┌──────────────┐       │
│ │Cloud │      │Container │   │ kubectl  │   │   BinAuthz   │       │
│ │Build │──────│ Analysis │───│  apply   │───│  Admission   │       │
│ └──────┘      └──────────┘   └──────────┘   │  Controller  │       │
│    │               │                        └──────────────┘       │
│    ▼               ▼                               │               │
│ ┌──────────────────────────────┐                   │               │
│ │  Create Attestations         │                   ▼               │
│ │  • "built-by-cloudbuild"     │          ┌──────────────┐         │
│ │  • "scan-ok"                 │          │   Validate   │         │
│ └──────────────────────────────┘          │   Against    │         │
│              │                            │   Policy     │         │
│              ▼                            └──────────────┘         │
│    ┌──────────────────┐                           │                │
│    │Container Analysis│◀──────────────────  Check Digest           │
│    │    (Storage)     │                                            │
│    └──────────────────┘                                            │
└────────────────────────────────────────────────────────────────────┘
```

### Comparison: Binary Authorization vs Kyverno + Cosign

| Feature | Binary Authorization | Kyverno + Cosign |
|---------|---------------------|------------------|
| **Type** | Managed service | DIY |
| **Platform Support** | GKE, Anthos, Cloud Run | Kubernetes only |
| **Attestation Storage** | Container Analysis API | Registry (OCI artifacts) |
| **Key Management** | Cloud KMS | Multi-cloud (KMS, Vault, etc.) |
| **Offline Validation** | ❌ Not possible | ✅ Supported |
| **Ease of Demo** | Difficult | Easy |
| **Org Policy Support** | ✅ Yes | ❌ No |
| **Cosign Compatibility** | ❌ Not currently | ✅ Native |
| **Trivy Integration** | Via Container Analysis | ✅ Direct support |
| **Setup Complexity** | Medium (IAM, APIs) | High (security hardening) |

### SLSA Level Support

[SLSA](https://slsa.dev/) (Supply chain Levels for Software Artifacts) defines four levels of increasing supply chain security:

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                           SLSA Levels Overview                                │
├───────┬───────────────────────────────────────────────────────────────────────┤
│ Level │ Requirements                                                          │
├───────┼───────────────────────────────────────────────────────────────────────┤
│   0   │ No guarantees (default state)                                         │
├───────┼───────────────────────────────────────────────────────────────────────┤
│   1   │ Documentation: Build process is documented and provenance exists      │
│       │ • Provenance generated (who, what, when)                              │
│       │ • Build process defined                                               │
├───────┼───────────────────────────────────────────────────────────────────────┤
│   2   │ Tamper Resistance: Hosted build service, signed provenance            │
│       │ • Hosted build platform (e.g., Cloud Build, GitHub Actions)           │
│       │ • Provenance authenticated and non-falsifiable                        │
│       │ • Version controlled source                                           │
├───────┼───────────────────────────────────────────────────────────────────────┤
│   3   │ Hardened Builds: Isolated, ephemeral build environment                │
│       │ • Builds run in isolated, ephemeral environments                      │
│       │ • Source integrity verified                                           │
│       │ • Provenance is unforgeable                                           │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

**SLSA Support by Tool:**

```
┌─────────────────────────┬──────────────────────────────────────────────────────┐
│ Tool                    │ SLSA Support                                         │
├─────────────────────────┼──────────────────────────────────────────────────────┤
│ Kyverno + Cosign        │ ✅ SLSA 1: Can verify basic provenance               │
│                         │ ✅ SLSA 2: Can verify signed provenance              │
│                         │ ✅ SLSA 3: Can verify SLSA GitHub Generator          │
│                         │ • Uses SLSA GitHub Generator for SLSA 3 builds       │
│                         │ • Verifies in-toto attestations                      │
│                         │ • Supports keyless signing via Sigstore              │
├─────────────────────────┼──────────────────────────────────────────────────────┤
│ Binary Authorization    │ ✅ SLSA 1: Via Cloud Build provenance                │
│                         │ ✅ SLSA 2: Via signed attestations                   │
│                         │ ⚠️ SLSA 3: Via Cloud Build + custom attestors        │
│                         │ • Integrates with Cloud Build provenance             │
│                         │ • Uses Container Analysis for attestation storage    │
│                         │ • Requires custom attestors for full SLSA 3          │
├─────────────────────────┼──────────────────────────────────────────────────────┤
│ OPA Gatekeeper          │ ❌ No native SLSA support                            │
│                         │ • Requires external integration                      │
│                         │ • Can validate labels/annotations only               │
│                         │ • Use Binary Authorization for SLSA on GKE           │
└─────────────────────────┴──────────────────────────────────────────────────────┘
```

**Recommended SLSA Implementation Paths:**

| Target Level | Kyverno Path | GCP Native Path |
|--------------|--------------|-----------------|
| **SLSA 1** | Cosign + basic provenance | Cloud Build with provenance enabled |
| **SLSA 2** | SLSA GitHub Generator + Kyverno verification | Cloud Build + Binary Authorization |
| **SLSA 3** | SLSA GitHub Generator (container workflow) + Kyverno | Cloud Build (isolated workers) + Binary Authorization + Custom Attestors |

**Example: Kyverno SLSA 3 Verification Policy:**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-slsa-level-3
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-slsa3-provenance
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/my-org/*"
          attestations:
            - predicateType: https://slsa.dev/provenance/v1
              attestors:
                - entries:
                    - keyless:
                        subject: "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*"
                        issuer: "https://token.actions.githubusercontent.com"
              conditions:
                - all:
                    - key: "{{ buildDefinition.buildType }}"
                      operator: Equals
                      value: "https://slsa-framework.github.io/github-actions-buildtypes/workflow/v1"
                    - key: "{{ runDetails.builder.id }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v1.9.0"
```

---

## CI/CD Integration

### Kyverno CLI

The Kyverno CLI can be used in CI/CD pipelines for "shift-left" policy validation:

```bash
# Apply policy to a resource file
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml

# Apply policy against a running cluster
kyverno apply /path/to/policy.yaml --cluster

# Apply policies from one cluster to another
kubectl get clusterpolicies -o yaml --context other-cluster | kyverno apply - --cluster

# Mutate resources offline (preview changes)
kyverno apply /path/to/policy.yaml --resource /path/to/resource.yaml -o newresource.yaml

# Test policies (for CI pipelines)
kyverno test /path/to/test-dir/
```

**CI/CD Pipeline Integration:**

```
┌─────────────────────────────────────────────────────────────┐
│                      Developer Workflow                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Developer         Pre-commit         CI Pipeline           │
│      │                 │                   │                │
│      ▼                 ▼                   ▼                │
│  ┌───────┐       ┌──────────┐       ┌──────────┐            │
│  │ Write │       │ kyverno  │       │ kyverno  │            │
│  │ YAML  │──────▶│  test    │──────▶│  apply   │            │
│  └───────┘       └──────────┘       │ --cluster│            │
│                       │             └──────────┘            │
│                       ▼                  │                  │
│                 ┌──────────┐             ▼                  │
│                 │  Notify  │       ┌──────────┐             │
│                 │Developer │       │  Deploy  │             │
│                 └──────────┘       └──────────┘             │
└─────────────────────────────────────────────────────────────┘
```

**Use Cases:**
- **Developers**: Test resources against policies before committing ("shift left")
- **Operators**: Test validation/mutation before version or policy updates
- **CI Systems**: Validate manifests in pull request checks

---

## Policy Examples Side-by-Side

### Example 1: Require Labels

#### Kyverno (~20 lines)
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Labels 'app' and 'env' are required"
        pattern:
          metadata:
            labels:
              app: "?*"
              env: "?*"
```

#### Gatekeeper (~40 lines combined)

**ConstraintTemplate:**
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing labels: %v", [missing])
        }
```

**Constraint:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-labels
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels:
      - "app"
      - "env"
```

### Example 2: Default Network Policy Generation (Kyverno Only)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-default-network-policy
spec:
  rules:
    - name: generate-netpol
      match:
        any:
          - resources:
              kinds:
                - Namespace
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-all
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
```

> **Note:** Gatekeeper cannot generate resources - this is a Kyverno-only feature.

---

## Performance Considerations

### Kyverno

| Aspect | Performance |
|--------|-------------|
| Startup Time | Moderate (loads policies from CRDs) |
| Policy Evaluation | Fast for simple patterns |
| Memory Usage | Moderate |
| Scaling | Horizontal scaling supported (replicas=3 recommended) |

**Optimization Tips:**
- Use `background: false` for policies that don't need background scanning
- Limit policy scope with namespace selectors
- Use `preconditions` to filter resources early
- Deploy with 3 replicas for production

### Gatekeeper

| Aspect | Performance |
|--------|-------------|
| Startup Time | Moderate (compiles Rego) |
| Policy Evaluation | Very fast (compiled Rego) |
| Memory Usage | Higher (OPA data cache) |
| Scaling | Horizontal scaling supported |

**Optimization Tips:**
- Optimize Rego queries for performance
- Use `sync` config to limit data synced to OPA
- Limit constraint scopes
- Use template library for common patterns

---

## Use Case Recommendations

### Choose Kyverno When:

1. **Your team is Kubernetes-focused**
   - YAML-based policies are easier to adopt
   - No need to learn a new language

2. **You need mutation capabilities**
   - Automatically fix non-compliant resources
   - Add default configurations

3. **You need resource generation**
   - Auto-create NetworkPolicies, ResourceQuotas, etc.
   - Ensure namespace consistency

4. **You need image verification with Cosign**
   - Built-in Cosign/Sigstore support
   - SLSA attestation verification
   - Supply chain security

5. **You want namespace-scoped policies**
   - Different policies for different teams
   - Multi-tenancy support

6. **You need policy exceptions**
   - "Break glass" scenarios for operations teams
   - Temporary bypasses with PolicyException

### Choose Gatekeeper (OPA) When:

1. **You need complex policy logic**
   - Data transformations
   - Cross-resource validation

2. **You use OPA elsewhere**
   - Consistent policy language across platforms
   - Reuse existing Rego policies

3. **You need multi-platform support**
   - VMs, Cloud Run, non-Kubernetes resources
   - Enterprise-wide policy consistency

4. **You want a managed service**
   - GKE/Anthos Config Management (ACM)
   - Policy Controller managed service

5. **Performance is critical**
   - Compiled Rego is very fast
   - Good for high-throughput clusters

6. **You have dedicated policy engineers**
   - Team familiar with Rego
   - Investment in policy-as-code

7. **You use ArgoCD or OpenShift**
   - Better integration support
   - Fewer known issues

---

## Customer Guidance

### Decision Matrix

```
┌─────────────────────────┬───────────────────────────────────────────────────────────────┐
│ Customer Situation      │ Recommendation                                                │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Already knows Rego      │ Push for OPA Gatekeeper, emphasize managed service            │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Already using Kyverno   │ Explain OPA Gatekeeper flexibility, highlight persona-focused │
│                         │ and managed services. If Kyverno chosen, help build secure    │
│                         │ pipeline with Artifact Registry and KMS                       │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Wants to implement SLSA │ Run a Software Delivery workshop for full supply chain        │
│                         │ overview. Emphasize Binary Authorization and Artifact Registry│
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Needs Cloud Run support │ OPA Gatekeeper or Binary Authorization                        │
│                         │ (Kyverno doesn't support Cloud Run)                           │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Multi-cloud environment │ Kyverno + Cosign for multi-cloud key management               │
├─────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Simple Kubernetes-only  │ Kyverno for ease of adoption                                  │
└─────────────────────────┴───────────────────────────────────────────────────────────────┘
```

### Open Considerations

1. **Personas and RBAC**: How do multiple personas (DevOps, Security, Platform) collaborate with Kyverno policies?
2. **Enterprise Scale**: Kyverno requires extra security work to deploy at scale
3. **GitOps**: Both support GitOps, but ConfigSync integration varies
4. **Trivy Integration**: Kyverno can validate vulnerabilities reported by Trivy (competes with Artifact Registry vulnerability scanning)

---

## Integration with Gateway API

Both Kyverno and Gatekeeper can enforce policies on Gateway API resources.

### Require TLS on Gateways

**Kyverno:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-gateway-tls
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-https-listener
      match:
        any:
          - resources:
              kinds:
                - Gateway
              namespaces:
                - apps
      validate:
        message: "Gateways must have HTTPS listeners"
        pattern:
          spec:
            listeners:
              - protocol: HTTPS
                tls:
                  mode: Terminate
```

**Gatekeeper:**
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiregatewaytls
spec:
  crd:
    spec:
      names:
        kind: K8sRequireGatewayTLS
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiregatewaytls
        violation[{"msg": msg}] {
          input.review.object.kind == "Gateway"
          listeners := input.review.object.spec.listeners
          not has_https(listeners)
          msg := "Gateway must have at least one HTTPS listener"
        }
        has_https(listeners) {
          l := listeners[_]
          l.protocol == "HTTPS"
        }
```

---

## Summary

| Criteria | Kyverno | OPA Gatekeeper |
|----------|---------|----------------|
| **Best For** | Paltform teams | Platform teams |
| **Policy Complexity** | Simple to Medium | Medium to Complex |
| **Learning Investment** | Low | High |
| **Mutation/Generation** | Excellent | Limited |
| **Image Verification** | Excellent (Cosign) | Requires extension |
| **Policy Reusability** | Kubernetes only | Cross-platform |
| **Community** | Growing fast | Mature |
| **CNCF Status** | Incubating | Graduated |
| **Managed Service** | ❌ DIY | ✅ GKE/ACM |

### Final Recommendation

- **Start with Kyverno** if you're new to Kubernetes policy engines and need quick adoption
- **Choose Gatekeeper** if you have existing OPA investment, need complex policy logic, or require a managed service
- **Consider both** for different use cases - they can coexist in the same cluster
- **For supply chain security**: Evaluate Kyverno + Cosign vs Binary Authorization based on your platform requirements

---

## Resources

### Kyverno
- [Official Documentation](https://kyverno.io/docs/)
- [Policy Library](https://kyverno.io/policies/)
- [GitHub Repository](https://github.com/kyverno/kyverno)
- [SLSA GitHub Generator](https://github.com/slsa-framework/slsa-github-generator)

### Gatekeeper
- [Official Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Constraint Library](https://github.com/open-policy-agent/gatekeeper-library)
- [GitHub Repository](https://github.com/open-policy-agent/gatekeeper)
- [ACM Policy Controller](https://cloud.google.com/anthos-config-management/docs/concepts/policy-controller)

### Supply Chain Security
- [Sigstore/Cosign](https://docs.sigstore.dev/)
- [Binary Authorization](https://cloud.google.com/binary-authorization/docs)
- [SLSA Framework](https://slsa.dev/)

### Gateway API
- [Official Documentation](https://gateway-api.sigs.k8s.io/)
- [GKE Gateway Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)
