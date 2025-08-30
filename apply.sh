#!/bin/bash

# Run the environment check script to ensure required environment variables, tools, or configurations are present.
./check_env.sh
if [ $? -ne 0 ]; then
  # If the check_env script exits with a non-zero status, it indicates a failure.
  echo "ERROR: Environment check failed. Exiting."
  exit 1  # Stop script execution immediately if environment check fails.
fi

# Phase 1 of the build - Build active directory
cd 01-directory

# Initialize Terraform (download providers, set up backend, etc.).
terraform init

# Apply the Terraform configuration, automatically approving all changes (no manual confirmation required).
terraform apply -auto-approve

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

# Return to the previous (parent) directory.
cd ..

# Log a note that the script will attempt to retrieve the domain administrator password.
echo "NOTE: Retrieving domain password for mcloud.mikecloud.com."

# Attempt to fetch the latest version of the 'admin-ad-credentials' secret from Google Cloud Secret Manager.
# Redirect errors to /dev/null to suppress warnings if the secret doesn't exist.
# If the secret doesn't exist, this command will still succeed (with empty output), thanks to '|| true'.
admin_credentials=$(gcloud secrets versions access latest --secret="admin-ad-credentials" 2> /dev/null || true)

# Check if the secret retrieval returned an empty string (meaning the secret does not yet exist).
if [[ -z "$admin_credentials" ]]; then
   # If no credentials exist, it means we need to reset the admin password for the Managed AD domain.

   echo "NOTE: Credentials need to be reset for 'mcloud.mikecloud.com'"

   # Use gcloud to reset the domain's admin password, outputting the result in JSON format.
   # --quiet suppresses interactive prompts.
   output=$(gcloud active-directory domains reset-admin-password "mcloud.mikecloud.com" --quiet --format=json)

   # Extract the new password from the JSON response using jq.
   admin_password=$(echo "$output" | jq -r '.password')

   # If the password is empty (unexpected case), fail and exit.
   if [[ -z "$admin_password" ]]; then
    	echo "ERROR: Failed to retrieve admin password for mcloud.mikecloud.com"
    	exit 1
   fi

   # Define the expected admin username in the correct format (domain\user).
   username="MCLOUD\\setupadmin"

   # Construct a JSON payload containing the username and the newly reset password.
   json_payload=$(jq -n \
        --arg username "$username" \
        --arg password "$admin_password" \
        '{username: $username, password: $password}')

   # Log that the script will now store the new credentials in Secret Manager.
   echo "NOTE: Storing new admin-ad-credentials secret..."

   # Pipe the JSON payload directly into gcloud to create a new version of the 'admin-ad-credentials' secret.
   echo "$json_payload" | gcloud secrets versions add admin-ad-credentials --data-file=-

   # Confirm that the secret was successfully updated.
   echo "NOTE: 'admin-ad-credentials' secret has been updated."
else
   # If the secret already exists, log a note that no password reset was needed.
   echo "NOTE: 'admin-ad-credentials' secret already exists. No action taken."
fi

# Phase 2 of the build - Build VMs connected to active directory
cd 02-servers

# Initialize Terraform (download providers, set up backend, etc.) for server deployment.
terraform init

# Apply the Terraform configuration, automatically approving all changes (no manual confirmation required).
terraform apply -auto-approve

# Return to the parent directory once server provisioning is complete.
cd ..
