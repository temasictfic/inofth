#!/bin/bash
set -e

# Ensure local bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

echo "=== K3d Setup Script (Cgroup v2 Compatible) ==="
echo ""

# Cleanup
echo "Cleaning up any existing clusters..."
k3d cluster delete iot 2>/dev/null || true
docker rm -f $(docker ps -aq -f name=k3d-iot) 2>/dev/null || true
docker network rm k3d-iot 2>/dev/null || true
sleep 2

echo ""
echo "Creating K3d cluster with Cgroup v2 compatibility..."

# Try with systemd cgroup driver (best for Cgroup v2)
echo "Creating cluster with proper Cgroup v2 configuration..."
if ! k3d cluster create iot \
    --image rancher/k3s:v1.27.3-k3s1 \
    --port "8888:30080@server:0" \
    --timeout 180s \
    --wait \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--kubelet-arg=cgroup-driver=systemd@server:0"; then
    
    echo ""
    echo "First attempt failed. Trying with older K3s version..."
    
    # Cleanup
    k3d cluster delete iot 2>/dev/null || true
    sleep 2
    
    # Try with older K3s version
    if ! k3d cluster create iot \
        --image rancher/k3s:v1.25.11-k3s1 \
        --port "8888:30080@server:0" \
        --timeout 180s \
        --wait \
        --k3s-arg "--disable=traefik@server:0"; then
        
        echo ""
        echo "Second attempt failed. Trying minimal configuration..."
        
        # Cleanup
        k3d cluster delete iot 2>/dev/null || true
        sleep 2
        
        # Minimal setup with even older K3s
        k3d cluster create iot \
            --image rancher/k3s:v1.23.17-k3s1 \
            --no-lb \
            --timeout 240s \
            --k3s-arg "--disable=traefik@server:0"
    fi
fi

echo ""
echo "Waiting for cluster to stabilize..."
sleep 10

# Setup kubeconfig
export KUBECONFIG="$(k3d kubeconfig write iot)"

# Verify cluster
echo ""
echo "Verifying cluster..."
ATTEMPTS=0
MAX_ATTEMPTS=30
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        echo "✓ Cluster is ready!"
        kubectl get nodes
        break
    fi
    echo "Waiting for node to be ready... ($((ATTEMPTS+1))/$MAX_ATTEMPTS)"
    sleep 5
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "ERROR: Cluster did not become ready"
    echo "Checking cluster status..."
    k3d cluster list
    docker ps -a | grep k3d
    exit 1
fi

echo ""
echo "=== Creating namespaces ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespaces created"

echo ""
echo "=== Installing Argo CD ==="
echo "Downloading Argo CD manifests..."

# Use a specific stable version of Argo CD
ARGOCD_VERSION="v2.8.4"
curl -sSL -o /tmp/argocd-install.yaml "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "Applying Argo CD manifests..."
kubectl apply -n argocd -f /tmp/argocd-install.yaml

echo ""
echo "Waiting for Argo CD pods to start..."
sleep 20

# Wait for deployments
echo "Waiting for Argo CD deployments..."
for deployment in argocd-server argocd-repo-server argocd-redis; do
    echo "  Waiting for $deployment..."
    kubectl wait --for=condition=available deployment/$deployment -n argocd --timeout=180s || true
done

echo ""
echo "=== Configuring Argo CD Application ==="
if [ -f "confs/argocd-app.yaml" ]; then
    echo "Applying Argo CD application configuration..."
    kubectl apply -f confs/argocd-app.yaml || {
        echo "Note: Make sure to update the GitHub repository URL in confs/argocd-app.yaml"
    }
else
    echo "Warning: confs/argocd-app.yaml not found"
fi

echo ""
echo "=== Getting Argo CD Password ==="
echo "Waiting for password secret..."
sleep 5

echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Still creating..."
echo ""

echo ""
echo "==================================================================="
echo "                    SETUP COMPLETE!"
echo "==================================================================="
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
echo "Namespaces:"
kubectl get ns | grep -E "(argocd|dev)" || true
echo ""
echo "Argo CD Pods:"
kubectl get pods -n argocd --no-headers 2>/dev/null | head -5 || echo "Still starting..."
echo ""
echo "To access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Open: https://localhost:8080"
echo ""
echo "To test the application (once deployed):"
echo "  curl http://localhost:8888"
echo ""
echo "To check application deployment:"
echo "  kubectl get application -n argocd"
echo "  kubectl get pods -n dev"
echo ""
echo "IMPORTANT: Make sure you have:"
echo "1. Created your GitHub repository with deployment.yaml"
echo "2. Updated confs/argocd-app.yaml with your repo URL"
echo "3. Pushed your deployment.yaml to GitHub"
echo "==================================================================="