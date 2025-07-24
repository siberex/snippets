#!/bin/bash

# Create encrypted systemd credential
# See also: https://systemd.io/CREDENTIALS/

# Usage:
# ./credential.sh --name="MYSQL_PASSWORD" --value="secretMYSQLpasswordEXAMPLE"
# Or:
# ./credential.sh MYSQL_PASSWORD secretMYSQLpasswordEXAMPLE

# Prerequisites:
# chmod +x credential.sh
# ls -al /var/lib/systemd/credential.secret
# mkdir "$HOME/.credentials"
# sudo chmod 700 "$HOME/.credentials"
# vim $HOME/.bashrc
# export CREDENTIALS_DIRECTORY="$HOME/.credentials"

set -e

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name=*)
                name="${1#*=}"
                shift
                ;;
            --value=*)
                value="${1#*=}"
                shift
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                elif [[ -z "$value" ]]; then
                    value="$1"
                else
                    echo "Error: Too many arguments" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    if [[ -z "$name" || -z "$value" ]]; then
        echo "Usage: $0 [--name=NAME] [--value=VALUE]" >&2
        echo "Compact: $0 NAME VALUE" >&2
        echo "Name should be valid alphanumeric filename. Underscores and dashes are allowed"
        echo "Example:" >&2
        echo "  $0 MYSQL_PASSWORD secretMYSQLpasswordEXAMPLE" >&2
        echo "  $0 --name=\"MYSQL_PASSWORD\" --value=\"secretMYSQLpasswordEXAMPLE\"" >&2
        exit 1
    fi

    # Basic check to validate filename
    if [[ ! "$name" =~ ^[a-zA-Z0-9_\-]+$ ]]; then
        echo "Error: Invalid credential name. Only alphanumeric, underscores and hyphens are allowed." >&2
        exit 1
    fi
}

# Check credentials directory
check_credentials_dir() {
    if [[ -z "$CREDENTIALS_DIRECTORY" ]]; then
        echo "Error: CREDENTIALS_DIRECTORY environment variable is not set" >&2
        exit 1
    fi

    if [[ ! -d "$CREDENTIALS_DIRECTORY" ]]; then
        echo "Error: CREDENTIALS_DIRECTORY '$CREDENTIALS_DIRECTORY' is not a directory path" >&2
        exit 1
    fi

    if [[ ! -w "$CREDENTIALS_DIRECTORY" ]]; then
        echo "Error: CREDENTIALS_DIRECTORY '$CREDENTIALS_DIRECTORY' is not writable by the current user" >&2
        exit 1
    fi
}

# Check for systemd-creds executable
check_systemd_creds() {
    if ! command -v systemd-creds >/dev/null 2>&1; then
        echo "Error: systemd-creds executable not found" >&2
        exit 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    check_credentials_dir
    check_systemd_creds

    output_file="${CREDENTIALS_DIRECTORY}/${name}.encrypted"

    echo -n "$value" | sudo systemd-creds encrypt --name="$name" - - | tee "$output_file" >/dev/null
    chmod 600 "$output_file"

    if [[ ! -s "$output_file" ]]; then
        echo "Error: Failed to create credential file or file is empty" >&2
        exit 1
    fi

    echo "Successfully stored encrypted credential in $output_file"
    echo "Use in your service with:"
    echo "LoadCredentialEncrypted=${name}:${output_file}"
}

main "$@"