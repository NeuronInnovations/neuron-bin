#!/bin/bash

# Define paths and GitHub repo base URL
DIR="$(dirname "$0")"  # Gets the directory of the script
ENV_FILE="$DIR/.env"
GITHUB_REPO_BASE="https://github.com/NeuronInnovations/neuron-bin/raw/main"  # Base URL for direct downloads from the repository
LOG_FILE="$DIR/neuron-sdk.log"  # Log file for storing output
MAX_LOG_LINES=1000  # Maximum number of lines to keep in the log file
LOG_TRUNCATE_INTERVAL=60  # Time in seconds between each log truncation

# Command line parameters for the OS and architecture (e.g., linux, darwin and amd64, arm, arm64)
OS_SUFFIX=$1
ARCH_SUFFIX=$2

# Check if both OS and architecture suffixes are provided
if [ -z "$OS_SUFFIX" ] || [ -z "$ARCH_SUFFIX" ]; then
    echo "Error: You must provide both an OS suffix (e.g., linux, darwin) and an architecture suffix (e.g., amd64, arm, arm64)."
    exit 1
fi

# Define the executable path dynamically based on the OS and architecture suffix
EXECUTABLE_PATH="$DIR/neuron-sdk-$OS_SUFFIX-$ARCH_SUFFIX"

# Function to fetch the latest version tag from GitHub
fetch_latest_version() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Use grep without -P option
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/NeuronInnovations/neuron-bin/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        # Linux: Use grep with -P option (Perl-compatible regular expressions)
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/NeuronInnovations/neuron-bin/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    fi

    if [ -z "$LATEST_VERSION" ]; then
        exit_on_error "Failed to fetch the latest release version from GitHub."
    fi
}

# Function to read the local_version from the .env file
read_local_version() {
    if [ -f "$ENV_FILE" ]; then
        local_version=$(grep -E '^local_version=' "$ENV_FILE" | cut -d '=' -f 2)
        if [ -z "$local_version" ]; then
            local_version=0  # If local_version is not found or is empty, set to 0
        fi
    else
        echo "Error: Environment file $ENV_FILE not found!"
        exit 1
    fi
}

# Function to stop the script with an error message
exit_on_error() {
    echo "Error: $1"
    exit 1
}

# Function to update the local_version in the .env file
update_local_version() {
    LATEST_VERSION=$1

    # If local_version exists, replace it; if not, add it to the .env file
    if grep -q '^local_version=' "$ENV_FILE"; then
        # Update existing local_version
        sed "s/^local_version=.*/local_version=$LATEST_VERSION/" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE" || exit_on_error "Failed to update the .env file."
    else
        # Add local_version to the .env file if not present
        echo -e "\nlocal_version=$LATEST_VERSION" >> "$ENV_FILE" || exit_on_error "Failed to add version to the .env file."
    fi
}

# Fetch the latest version from GitHub
fetch_latest_version

# Read the local_version from the .env file
read_local_version

# Check if the GitHub version is newer than the local version
if [ "$LATEST_VERSION" != "$local_version" ]; then
    echo "A new version is available: $LATEST_VERSION. Downloading the latest version."

    # Construct the URL to download the executable directly from the repo folder
    EXECUTABLE_URL="$GITHUB_REPO_BASE/$OS_SUFFIX/$ARCH_SUFFIX/neuron-sdk-$OS_SUFFIX-$ARCH_SUFFIX"

    echo "Downloading neuron-sdk for $OS_SUFFIX-$ARCH_SUFFIX from $EXECUTABLE_URL..."

    # Download the executable directly from the repo folder
    curl -L "$EXECUTABLE_URL" -o "$EXECUTABLE_PATH" || exit_on_error "Failed to download neuron-sdk for $OS_SUFFIX-$ARCH_SUFFIX."

    # Make sure the downloaded executable has the correct permissions
    chmod +x "$EXECUTABLE_PATH" || exit_on_error "Failed to set executable permissions."

    # Update the .env file with the new version
    update_local_version "$LATEST_VERSION"
    
    echo "Download completed. Updated local_version to $LATEST_VERSION."
else
    echo "local_version is up-to-date: $local_version. No need to download."
fi


# Function to run the executable and monitor it, handling macOS and Linux differences
run_executable() {
    while true; do
        echo "Starting neuron-sdk-$OS_SUFFIX-$ARCH_SUFFIX..."
        chmod +x "$EXECUTABLE_PATH"

        # Start the executable in the background
        "$EXECUTABLE_PATH" "${PARAMS[@]}" &

        EXECUTABLE_PID=$!
        
      

        # Wait for the executable to stop running
        wait $EXECUTABLE_PID
        EXEC_EXIT_CODE=$?

        # Kill the log truncation process when the executable stops
        kill $LOG_TRUNCATION_PID

        if [ $EXEC_EXIT_CODE -ne 0 ]; then
            echo "The neuron-sdk-$OS_SUFFIX-$ARCH_SUFFIX has exited with status code $EXEC_EXIT_CODE. Restarting in 10 seconds..."
        else
            echo "The neuron-sdk-$OS_SUFFIX-$ARCH_SUFFIX exited normally. Exiting the script."
            break
        fi
        sleep 10  # Delay before restarting the executable
    done
}

# Combine fixed parameters with user-supplied overrides (if any)
PARAMS=(-buyer-or-seller=buyer -mode=peer -port=1352 -buyer-udp-address=localhost:1234 "${@:3}")

# Start the monitoring loop
run_executable