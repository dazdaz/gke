#!/bin/bash

# Define variables
PROJECT_ID=<myproject>
CLUSTER_NAME=<mylcuster>
KSA_NAME="gke-${CLUSTER_NAME}-service-account"
GSA_NAME="gke-${CLUSTER_NAME}-gcs-accessor"
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
NAMESPACE="default"
INPUT_BUCKET="transcode-preprocessing-bucket"
OUTPUT_BUCKET="transcode-postprocessing-bucket"

# --- REMOVE IAM ROLES ON GCS BUCKETS ---
# Remove the objectAdmin and objectViewer roles from the GSA for the input bucket
echo "Removing objectAdmin and objectViewer roles from input bucket..."
gcloud storage buckets remove-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets remove-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer"

# Remove the objectAdmin and objectViewer roles from the GSA for the output bucket
echo "Removing objectAdmin and objectViewer roles from output bucket..."
gcloud storage buckets remove-iam-policy-binding gs://${OUTPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets remove-iam-policy-binding gs://${OUTPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer"

# --- REMOVE WORKLOAD IDENTITY BINDINGS ---
# Remove the iam.workloadIdentityUser role binding from the GSA
echo "Removing Workload Identity user binding from GSA..."
gcloud iam service-accounts remove-iam-policy-binding ${GSA_EMAIL} \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
    --project=${PROJECT_ID}

# --- REMOVE KSA ANNOTATION AND KSA ---
# Remove the Workload Identity annotation from the Kubernetes Service Account
echo "Removing Workload Identity annotation from KSA..."
kubectl annotate serviceaccount ${KSA_NAME} \
    iam.gke.io/gcp-service-account- \
    --namespace=${NAMESPACE}

# Delete the Kubernetes Service Account
echo "Deleting the Kubernetes Service Account..."
kubectl delete serviceaccount ${KSA_NAME} --namespace ${NAMESPACE}

echo "Cleanup complete."
