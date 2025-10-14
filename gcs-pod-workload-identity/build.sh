gcloud builds submit . --config=cloudbuild.yaml --substitutions=_PROJECT_ID=myproject,_REGION=europe-west4,_GKE_CLUSTER=mycluster
