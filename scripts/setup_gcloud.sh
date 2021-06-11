#!/usr/bin/env bash

# Usage: scripts/setup_gcloud.sh [PROJECT_ID]

set -euo pipefail

BASEDIR="$( cd "$(dirname "$0")" || true ; pwd -P )"

GOOGLE_CLOUD_PROJECT=${1:-$(gcloud config list --format 'value(core.project)')}

ROLE_ID=appengine_deployer_gh_actions
SERVICE_ACCOUNT=github-actions-deployment

SERVICE_ACCOUNT_EMAIL=${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com

if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_CLOUD_PROJECT}" > /dev/null 2>&1; then
    echo "✓ Found Role ${ROLE_ID} in project ${GOOGLE_CLOUD_PROJECT}"
else
    echo "… Creating Role ${ROLE_ID} in project ${GOOGLE_CLOUD_PROJECT}"
    gcloud iam roles create "${ROLE_ID}" --file="$BASEDIR/appengine_deployer_role.yml" --project="${GOOGLE_CLOUD_PROJECT}"
fi

if gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" --project="${GOOGLE_CLOUD_PROJECT}" > /dev/null 2>&1; then
  echo "✓ Found Service Account ${SERVICE_ACCOUNT_EMAIL}"
else
  echo "… Creating Service Account ${SERVICE_ACCOUNT_EMAIL}"
  gcloud iam service-accounts create "${SERVICE_ACCOUNT}" --display-name="${SERVICE_ACCOUNT}" --description="Account to deploy via GitHub Actions" --project="${GOOGLE_CLOUD_PROJECT}"
fi

gcloud projects add-iam-policy-binding "${GOOGLE_CLOUD_PROJECT}" --member="serviceAccount:github-actions-deployment@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com" --role="projects/${GOOGLE_CLOUD_PROJECT}/roles/appengine_deployer_gh_actions" --condition=None

TMP_OUTPUT_FILE="$(mktemp)"

gcloud iam service-accounts keys create "${TMP_OUTPUT_FILE}" --iam-account "github-actions-deployment@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

printf "\nGCLOUD_PROJECT_ID: %s\n" "${GOOGLE_CLOUD_PROJECT}"
printf "\nGCP_SA_EMAIL: %s\n" "github-actions-deployment@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
printf "\nGOOGLE_APPLICATION_CREDENTIALS (copy all lines):\n\n%s\n\n" "$(base64 "${TMP_OUTPUT_FILE}")"