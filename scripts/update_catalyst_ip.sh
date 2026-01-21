#!/bin/bash

# Define the hostname alias
HOST_ALIAS="catalystip"
HOSTS_FILE="/etc/hosts"

# Get the primary IP address (excluding loopback)
# This gets the first IP found on the main interface (usually eth0 or ens33)
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -z "$CURRENT_IP" ]; then
    echo "Could not detect IP address."
    exit 1
fi

echo "Detected Current IP: $CURRENT_IP"

# Check if catalystip already exists in /etc/hosts
if grep -q "$HOST_ALIAS" "$HOSTS_FILE"; then
    echo "Updating existing $HOST_ALIAS entry..."
    # Update the existing line: replace the whole line containing catalystip
    # We use sudo sed to edit in place.
    sudo sed -i "s/.*$HOST_ALIAS$/$CURRENT_IP $HOST_ALIAS/" "$HOSTS_FILE"
else
    echo "Adding new $HOST_ALIAS entry..."
    # Append the new entry
    echo "$CURRENT_IP $HOST_ALIAS" | sudo tee -a "$HOSTS_FILE" > /dev/null
fi

# Verify
echo "Updated /etc/hosts:"
grep "$HOST_ALIAS" "$HOSTS_FILE"
