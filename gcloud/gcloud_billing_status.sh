# List all projects with assigned billing and status
gcloud beta billing accounts list --format 'value(ACCOUNT_ID)' | while read -r BILLING_ACCOUNT_ID; do
    gcloud beta billing projects list --billing-account "$BILLING_ACCOUNT_ID" --format 'value(PROJECT_ID, BILLING_ACCOUNT_ID, BILLING_ENABLED)'
done

# Check if billing is enabled for Project Id
GOOGLE_CLOUD_PROJECT=${1:-$(gcloud config list --format 'value(core.project)')}

function isBillingEnabled() {
  GOOGLE_CLOUD_PROJECT=$1
  BILLING_ACCOUNTS_LIST=$(gcloud beta billing accounts list --format 'value(ACCOUNT_ID)')
  IFS=$'\n'; for BILLING_ACCOUNT_ID in $BILLING_ACCOUNTS_LIST; do
    res=$(gcloud beta billing projects list --billing-account "$BILLING_ACCOUNT_ID" --filter "billingEnabled=True AND projectId=$GOOGLE_CLOUD_PROJECT" --format="get(billingEnabled)" 2> /dev/null)
    if [[ "$res" =~ True ]]; then
      # echo "Billing is ENABLED - $GOOGLE_CLOUD_PROJECT / $BILLING_ACCOUNT_ID"
      return 0
    fi
  done
  false
}

if isBillingEnabled "$GOOGLE_CLOUD_PROJECT"; then
  echo "✓ Billing is enabled for Project $GOOGLE_CLOUD_PROJECT"
else
  echo "× Billing is NOT ENABLED for Project $GOOGLE_CLOUD_PROJECT"
fi
