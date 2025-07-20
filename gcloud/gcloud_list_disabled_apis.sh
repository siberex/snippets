#!/usr/bin/env bash

set -euo pipefail

GOOGLE_CLOUD_PROJECT=${1:-$(gcloud config list --format 'get(core.project)')}

PROJECT_NUMBER=$(gcloud projects describe "${GOOGLE_CLOUD_PROJECT}" --format 'get(projectNumber)')

alias gcurl='curl -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json"'

# https://cloud.google.com/service-usage/docs/list-services#disabled
# https://cloud.google.com/service-usage/docs/reference/rest/v1/services/list
gcurl "https://serviceusage.googleapis.com/v1/projects/${PROJECT_NUMBER}/services?filter=state:DISABLED&pageSize=200" | jq '.services[].config.name'

# FIXME: pagination






gcloud services list


NOW=$(TZ=GMT date +"%Y-%m-%dT%H:%M:%SZ")
gcloud asset list \
    --organization='ORGANIZATION_ID' \
    --billing-project='BILLING_PROJECT_ID' \
    --asset-types='serviceusage.googleapis.com/Service' \
    --snapshot-time=$NOW \
    --content-type='resource'
