#!/bin/bash

apk update
apk add curl

echo "Installing K3s..."
# Install K3s in server mode with proper kubeconfig permissions
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

echo "Setting up K3s service..."
# Enable K3s service
rc-update add k3s default

# Start K3s service
rc-service k3s start

# Check if service started successfully
if ! rc-service k3s status | grep -q "started"; then
    echo "K3s service failed to start, trying manual start..."
    /usr/local/bin/k3s server --write-kubeconfig-mode 644 &
    sleep 10
fi

TOKEN_PATH="/vagrant/token"

echo "Waiting for K3s to initialize..."
# Wait for K3s to create necessary directories and files
timeout=60
counter=0
while [ ! -f /var/lib/rancher/k3s/server/node-token ] && [ $counter -lt $timeout ]; do
    sleep 2
    counter=$((counter + 2))
    echo "Still waiting for k3s to initialize... ($counter/$timeout seconds)"
done

if [ ! -f /var/lib/rancher/k3s/server/node-token ]; then
    echo "ERROR: K3s failed to initialize after $timeout seconds"
    echo "Checking processes:"
    ps aux | grep k3s
    echo "Checking logs:"
    tail -20 /var/log/k3s.log 2>/dev/null || echo "No log file found"
    exit 1
fi

echo "Waiting for API server to be ready..."
timeout=60
counter=0
until curl -k -s https://127.0.0.1:6443/readyz >/dev/null 2>&1 || [ $counter -ge $timeout ]; do
    sleep 3
    counter=$((counter + 3))
    echo "Waiting for API server... ($counter/$timeout seconds)"
done

if [ $counter -ge $timeout ]; then
    echo "ERROR: API server not ready after $timeout seconds"
    echo "Checking if K3s is running:"
    ps aux | grep k3s
    echo "Checking port 6443:"
    netstat -tlnp | grep 6443 || echo "Port 6443 not listening"
    exit 1
fi

# Copy the token to shared location
cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_PATH"
chmod 644 "$TOKEN_PATH"

echo "K3s server setup complete!"
echo "Node token saved to $TOKEN_PATH"
echo "API server is ready!"

# Test kubectl
echo "Testing kubectl..."
kubectl get nodes

echo "Setup completed successfully!"