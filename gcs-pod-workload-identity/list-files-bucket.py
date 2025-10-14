#!/usr/bin/env python3

import os
import sys
from google.cloud import storage
from google.auth import default
from google.auth.exceptions import DefaultCredentialsError

# --- Configuration ---
DEFAULT_INPUT_BUCKET = "transcode-preprocessing-bucket"
# --- End Configuration ---

def get_gcs_client_workload_identity():
    """
    Get an authenticated GCS client using Workload Identity credentials.
    """
    kubernetes_service_account = os.getenv('KUBERNETES_SERVICE_ACCOUNT', 'default (KSA env var not set)')

    print(f"Info: Kubernetes Service Account specified: '{kubernetes_service_account}'", file=sys.stderr)

    try:
        # On GKE with Workload Identity, this talks to the metadata server
        # to get credentials for the GSA linked to the KSA.
        credentials, project = default()

        # --- IMPROVED LOGIC ---
        # In a Workload Identity environment, the credentials object may not
        # directly expose the GSA email, often showing 'default'.
        # The actual identity is confirmed by the token used in the API call.
        # We'll provide a more accurate log message.
        print("Info: Attempting to authenticate using Workload Identity.", file=sys.stderr)
        print("Info: Successfully obtained Google Cloud credentials.", file=sys.stderr)

        client = storage.Client(credentials=credentials, project=project)
        return client

    except DefaultCredentialsError as e:
        print(f"Error: Could not obtain default Google Cloud credentials. "
              f"Ensure Workload Identity is configured correctly.\n{e}", file=sys.stderr)
        raise
    except Exception as e:
        print(f"An unexpected error occurred while getting GCS client: {e}", file=sys.stderr)
        raise

def list_bucket_files_workload_identity(bucket_name):
    """
    Lists files in a Google Cloud Storage bucket using Workload Identity.
    """
    print(f"Attempting to list files in bucket: gs://{bucket_name}/...")

    try:
        client = get_gcs_client_workload_identity()
        bucket = client.get_bucket(bucket_name)

        print("-" * 30)
        print(f"Files in bucket '{bucket_name}':")

        blobs = bucket.list_blobs()
        found_files = False
        for blob in blobs:
            if not blob.name.endswith('/'): # Skip directories
                print(f"  - {blob.name}")
                found_files = True

        if not found_files:
            print("  No files found in this bucket.")
        print("-" * 30)

    except Exception as e:
        print(f"\nAn error occurred during listing: {e}", file=sys.stderr)
        print("Please ensure the following:", file=sys.stderr)
        print(f"- The GSA has 'Storage Object Viewer' role on bucket '{bucket_name}'.", file=sys.stderr)
        print(f"- The GKE Pod is running with a correctly configured KSA.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    target_bucket = DEFAULT_INPUT_BUCKET
    list_bucket_files_workload_identity(target_bucket)
