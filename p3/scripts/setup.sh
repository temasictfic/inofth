#!/bin/bash
set -e

echo "=== Creating K3d cluster ==="
k3d cluster create iot --api-port 6443 --servers 1 --agents 0 --port "8888:30080@server:0" --wait

echo "=== Creating namespaces ==="
kubectl create namespace argocd
kubectl create namespace dev

echo "=== Installing Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "=== Deploying application ==="
kubectl apply -f confs/app.yaml

echo "=== Setting up Argo CD application ==="
kubectl apply -f confs/argocd-app.yaml

echo "=== Getting Argo CD password ==="
echo "Admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "Setup complete!"
echo "Access application: curl http://localhost:8888"
echo "Access Argo CD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
