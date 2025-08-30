#!/bin/bash

apk update
apk add curl

TOKEN_FILE="/vagrant/token"
SERVER_IP="192.168.56.110"

echo "Waiting for server to initialize and create token..."

# Wait for token file to exist and have content
while [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; do
     sleep 2
     echo "Waiting for token file..."
done

TOKEN=$(cat "$TOKEN_FILE")

echo "Token found, joining cluster as agent..."

# Install K3s in agent mode
curl -sfL https://get.k3s.io | K3S_URL="https://$SERVER_IP:6443" K3S_TOKEN="$TOKEN" sh -

echo "K3s agent setup complete!"
echo "Node should now be joined to the cluster."