```bash

PROJECT_ID=<myproject>
CLUSTER_NAME=<mylcuster>
KSA_NAME=gke-${CLUSTER_NAME}-service-account
GSA_NAME=gke-${CLUSTER_NAME}-gcs-accessor
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
NAMESPACE=default
INPUT_BUCKET=transcode-preprocessing-bucket
OUTPUT_BUCKET=transcode-postprocessing-bucket

# Create a Kubernetes Service Account (KSA)
kubectl create serviceaccount ${KSA_NAME} --namespace ${NAMESPACE}

# Allow the KSA to impersonate the GSA
gcloud iam service-accounts add-iam-policy-binding ${GSA_EMAIL} \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
    --project=${PROJECT_ID}

# Annotate the Kubernetes Service Account with the GSA email
kubectl annotate serviceaccount ${KSA_NAME} \
    iam.gke.io/gcp-service-account=${GSA_EMAIL} \
    --namespace=${NAMESPACE} \
    --overwrite

# Check that the annotation was successful
kubectl describe serviceaccount ${KSA_NAME}
# See full object definition
kubectl get serviceaccount ${KSA_NAME} -o yaml

# Bind IAM policy on the GSA to allow Workload Identity impersonation
gcloud iam service-accounts add-iam-policy-binding \
    ${GSA_EMAIL} \
    --role=roles/iam.workloadIdentityUser \
    --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]"

# Check the IAM policy binding on the GSA
gcloud iam service-accounts get-iam-policy ${GSA_EMAIL}

# Assign roles to the GSA for GCS bucket access
gcloud storage buckets add-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding gs://${OUTPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectAdmin"

gcloud storage buckets add-iam-policy-binding gs://${INPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer"

gcloud storage buckets add-iam-policy-binding gs://${OUTPUT_BUCKET} \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer"

# Check assigned permissions on the input bucket
gcloud storage buckets get-iam-policy gs://${INPUT_BUCKET}
```
