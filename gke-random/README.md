# gke

```
# rapid = required for Windows
# --enable-ip-alias required for windows

# gcloud projects create me-mygke-project --name=mygke --enable-cloud-apis --labels=contact=me-at-mydomain-com --folder=9876543210 --set-as-default
# gcloud beta billing projects link daev-mygke --billing-account 1234567890

gcloud services enable container.googleapis.com

gcloud beta container clusters create mygke \
    --machine-type=n1-standard-4 \
    --zone=europe-west4-a \
    --num-nodes=3 \
    --subnetwork=default \
    --release-channel rapid \
    --enable-ip-alias \
    --addons=HttpLoadBalancing,CloudRun \
    --enable-stackdriver-kubernetes \
    --scopes cloud-platform,cloud-source-repos-ro,storage-ro,logging-write,monitoring-write,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite

# If you require dataplane v2
gcloud container clusters create <cluster name> \
    --enable-dataplane-v2 \
    --release-channel rapid \
    --enable-ip-alias \ 
    --zone <zone name>

gcloud container clusters get-credentials mygke --zone europe-west4-a
ls -l ~/.kube/config

# Upgrade control plane to latest version in the release channel
gcloud container clusters upgrade mygke --master --cluster-version VERSION

# Upgrades node pool to same version as the control plane
gcloud container clusters upgrade mygke --zone europe-west4-a
```
