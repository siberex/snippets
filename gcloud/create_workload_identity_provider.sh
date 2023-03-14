#!/usr/bin/env bash
set -euo pipefail

# https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions
# https://cloud.google.com/iam/docs/configuring-workload-identity-federation
# https://github.com/marketplace/actions/authenticate-to-google-cloud#setup
# https://cloud.google.com/iam/docs/manage-workload-identity-pools-providers

# https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform
# https://github.com/marketplace/actions/authenticate-to-google-cloud#setting-up-workload-identity-federation


# Configuration
GOOGLE_CLOUD_PROJECT=${1:-$(gcloud config list --format 'value(core.project)')}

POOL_ID="github-deployment-pool"
GITHUB_USER="ORG_OR_USER_NAME"
GITHUB_REPO="${GITHUB_USER}/REPO_NAME"
SERVICE_ACCOUNT=github-actions-deployment
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"


# Prerequisites:
# Enable the APIs
# https://console.cloud.google.com/flows/enableapi?apiid=iam.googleapis.com,cloudresourcemanager.googleapis.com,iamcredentials.googleapis.com,sts.googleapis.com&redirect=https://console.cloud.google.com

#echo "Enabling the IAM Credentials API..."
#gcloud services enable iamcredentials.googleapis.com --project "${GOOGLE_CLOUD_PROJECT}"


gcloud iam workload-identity-pools create "${POOL_ID}" \
    --project="${GOOGLE_CLOUD_PROJECT}" \
    --location="global" \
    --description="GitHub Actions Deployment Identity Pool" \
    --display-name="GitHub Deployment"

# Get the full ID of the created Workload Identity Pool:
WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe "${POOL_ID}" \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --location="global" \
  --format="value(name)")


# Create a Workload Identity Provider `github-actions` in that pool:
gcloud iam workload-identity-pools providers create-oidc "github-actions" \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub Actions Identity Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.aud=assertion.aud" \
  --attribute-condition="attribute.actor=='${GITHUB_USER}' && attribute.repository=='${GITHUB_REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"


if gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" --project="${GOOGLE_CLOUD_PROJECT}" >/dev/null 2>&1; then
  echo -e "✓ Found Service Account ${SERVICE_ACCOUNT_EMAIL}"

  # Allow authentications from the Workload Identity Provider originating from your repository to impersonate the deployment Service Account:
  gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_EMAIL}" \
    --project="${GOOGLE_CLOUD_PROJECT}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${GITHUB_REPO}"
else
  echo "Service Account not found"
  exit 1
fi


echo "Getting Workload Identity Provider resource name..."

# Extract the Workload Identity Provider resource name:
gcloud iam workload-identity-pools providers describe "github-actions" \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --format="value(name)"
