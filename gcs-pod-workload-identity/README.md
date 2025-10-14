
## GKE Workload Identity Walkthrough


On GKE, run a pod which accesses a GCS bucket to list files using workload identity


This repository contains a test setup for running a media transcoding job on Google Kubernetes Engine (GKE) using Workload Identity to securely access Google Cloud Storage (GCS) buckets. The core components are a GKE Pod and a Cloud Build pipeline.

🚀 Overview
The purpose of this setup is to demonstrate the end-to-end process of:

* Building a Docker container that lists files in a GCS bucket.
* Pushing the container to Google's Artifact Registry.
* Deploying the container as a Pod on a GKE cluster.
* Using Workload Identity to grant the GKE Pod's Service Account access to GCS without requiring credentials or API keys.
* Using Python3, use the Storge API to list the objects in the bucket.

📂 Included Files
list-files-bucket-pod.yaml: A Kubernetes manifest for a Pod that runs a Python script to list files in a GCS bucket.
It's configured to use a specific Kubernetes Service Account (k8s_service_account).

The YAML file is setup to inject the credentials into the container via an environment variable which is read by the Python scrpipt.

```bash
apiVersion: v1
kind: Pod
metadata:
  name: gcs-lister-pod
spec:
  serviceAccountName: k8s_service_account
  restartPolicy: Never
  containers:
  - name: gcs-lister
    image: europe-west4-docker.pkg.dev/<myproject>/transcode-repo/list-files-bucket:latest
    command: ["python"]
    args: ["/app/list-files-bucket.py"]
    # Pass the service account's name to the container as an environment variable using the Kubernetes Downward API
    env:
    - name: KUBERNETES_SERVICE_ACCOUNT
      valueFrom:
        fieldRef:
          fieldPath: spec.serviceAccountName
```


cloudbuild.yaml: A Cloud Build configuration file that automates the entire workflow, including building the Docker image, pushing it,
and running the Pod on GKE.

01-setup-workload-identity.sh: A collection of gcloud and kubectl commands to set up the necessary Service Accounts and IAM policies for Workload Identity.

## 🛠️ Prerequisites
Before you begin, ensure you have:

A Google Cloud project with billing enabled.
A GKE cluster with Workload Identity enabled.
Each node pool must have workload identity enabled.
The gcloud and kubectl command-line tools installed.

If the response is anything other than GKE_METADATA then workload identity has not been enabled.
```bash
gcloud container node-pools describe NODE_POOL_NAME \
    --cluster=CLUSTER_NAME \
    --region=CLUSTER_REGION \
    --format="json(workloadMetadataConfig)"
GKE_METADATA
```

## ⚙️ Setup and Deployment
Follow these steps to configure your environment and run the test.

### Step 1: Create Service Accounts
Workload Identity requires a Kubernetes Service Account (KSA) and a Google Cloud Service Account (GSA).
The KSA will impersonate the GSA to gain access to Google Cloud resources.

Run the following commands, replacing the placeholder values with your specific project and cluster names:

```Bash
PROJECT_ID=myproject
CLUSTER_NAME=mycluster
KSA_NAME=gke-${CLUSTER_NAME}-service-account
GSA_NAME=gke-${CLUSTER_NAME}-gcs-accessor
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
NAMESPACE=default

# Create the Kubernetes Service Account
kubectl create serviceaccount ${KSA_NAME} --namespace ${NAMESPACE}
```

## Create the Google Cloud Service Account
```bash
gcloud iam service-accounts create ${GSA_NAME} --project=${PROJECT_ID}
```
### Step 2: Configure Workload Identity
Next, bind the GSA to the KSA so that the GKE Pod can use the GSA's permissions.

```Bash

# Allow the KSA to impersonate the GSA
gcloud iam service-accounts add-iam-policy-binding ${GSA_EMAIL} \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
    --project=${PROJECT_ID}

# Annotate the Kubernetes Service Account with the GSA's email
kubectl annotate serviceaccount ${KSA_NAME} \
    iam.gke.io/gcp-service-account=${GSA_EMAIL} \
    --namespace=${NAMESPACE} \
    --overwrite
```

### Step 3: Grant IAM roles for GCS bucket to GSA_EMAIL
Grant the GSA the necessary permissions to read and write to your GCS buckets.
The example code uses storage.objectViewer to list objects and storage.objectAdmin for write access.

```Bash
# Grant Viewer access to the input bucket
gcloud storage buckets add-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectAdmin"

# Grant Admin access to the output bucket (for writing)
gcloud storage buckets add-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer"
```

### Step 4: Run the Cloud Build Pipeline
Finally, trigger the Cloud Build pipeline to execute the entire workflow. This command will build the Docker image, push it to Artifact Registry, and run the Python script within a GKE Pod.

```Bash
gcloud builds submit . --config=cloudbuild.yaml \
    --substitutions=_PROJECT_ID=myproject,_REGION=europe-west4,_GKE_CLUSTER=mycluster
```
