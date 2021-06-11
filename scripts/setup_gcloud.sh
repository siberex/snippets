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

EXISTING_ROLE_BINDING=$(gcloud projects  get-iam-policy "${GOOGLE_CLOUD_PROJECT}" --flatten="bindings[].members" --format="value(bindings.role)" --filter="bindings.role:roles/${ROLE_ID} AND bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}")
if [ "${EXISTING_ROLE_BINDING}" = "projects/${GOOGLE_CLOUD_PROJECT}/roles/${ROLE_ID}" ]; then
    echo "✓ Binding exists: Role ${ROLE_ID} is already attached to Service Account ${SERVICE_ACCOUNT}"
else
    echo "… Creating IAM policy binding for ${SERVICE_ACCOUNT} and Role ${ROLE_ID}"
    gcloud projects add-iam-policy-binding "${GOOGLE_CLOUD_PROJECT}" --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="projects/${GOOGLE_CLOUD_PROJECT}/roles/${ROLE_ID}" --condition=None
fi

echo "… Creating new private key for Service Account ${SERVICE_ACCOUNT_EMAIL}"
TMP_OUTPUT_FILE="$(mktemp)"
gcloud iam service-accounts keys create "${TMP_OUTPUT_FILE}" --iam-account "github-actions-deployment@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

printf "\nGCLOUD_PROJECT_ID: %s\n" "${GOOGLE_CLOUD_PROJECT}"
printf "\nGCP_SA_EMAIL: %s\n" "github-actions-deployment@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
printf "\nGOOGLE_APPLICATION_CREDENTIALS (copy all lines):\n\n%s\n\n" "$(base64 "${TMP_OUTPUT_FILE}")"
rm "${TMP_OUTPUT_FILE}"