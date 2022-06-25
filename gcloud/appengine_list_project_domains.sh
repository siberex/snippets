#!/usr/bin/env bash

# App Engine: List all project regions and mapped domains

# Effectively:
# gcloud projects list --format 'get(PROJECT_ID)'
# gcloud app describe --project "$projectId" --format 'get(locationId)'
# gcloud app domain-mappings list --project "$projectId" --format 'get(ID)' | xargs | sed 's/ /, /g'

printf "%s\t%s\t%s\n" "ProjectId" "Region" "Domains"
gcloud projects list --format 'get(PROJECT_ID)' | while read -r projectId; do
  region=$(gcloud app describe --project "$projectId" --format 'get(locationId)' 2>/dev/null || echo 'N/A')
  domains=$((gcloud app domain-mappings list --project "$projectId" --format 'get(ID)' 2>/dev/null || echo 'N/A') | xargs | sed 's/ /, /g')
  printf "%s\t%s\t%s\n" "$projectId" "$region" "$domains"
done
