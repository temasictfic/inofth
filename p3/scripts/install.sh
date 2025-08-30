#!/bin/bash
set -e

echo "=== Installing kubectl and K3d locally (no sudo required) ==="

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create local bin directory if it doesn't exist
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Check if LOCAL_BIN is in PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo "Adding $LOCAL_BIN to PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    # Also add to current session
    export PATH="$LOCAL_BIN:$PATH"
    echo "✓ Added $LOCAL_BIN to PATH"
fi

echo ""
echo "Checking existing tools..."

# Check Docker
if command_exists docker; then
    echo "✓ Docker is already installed: $(docker --version)"
    if docker info >/dev/null 2>&1; then
        echo "  ✓ Docker daemon is accessible"
    else
        echo "  ⚠ Docker daemon is not accessible. You may need to:"
        echo "    - Start Docker service"
        echo "    - Or run: newgrp docker"
        echo "    - Or logout and login again"
    fi
else
    echo "✗ Docker not found. Please install Docker first."
    exit 1
fi

# Check Git
if command_exists git; then
    echo "✓ Git is already installed: $(git --version)"
else
    echo "✗ Git not found. Please install Git first."
    exit 1
fi

echo ""
echo "Installing missing tools..."

# Install kubectl locally if not present
if command_exists kubectl; then
    echo "✓ kubectl is already installed: $(kubectl version --client --short 2>/dev/null || echo "installed")"
else
    echo "Installing kubectl to $LOCAL_BIN..."
    
    # Download kubectl
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    echo "  Downloading kubectl ${KUBECTL_VERSION}..."
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Make executable and move to local bin
    chmod +x kubectl
    mv kubectl "$LOCAL_BIN/"
    
    echo "✓ kubectl installed successfully to $LOCAL_BIN/kubectl"
fi

# Install K3d locally if not present
if command_exists k3d; then
    echo "✓ K3d is already installed: $(k3d version | grep "k3d version" | head -1)"
else
    echo "Installing K3d to $LOCAL_BIN..."
    
    # Download and install K3d without sudo
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | USE_SUDO=false K3D_INSTALL_DIR="$LOCAL_BIN" bash
    
    echo "✓ K3d installed successfully to $LOCAL_BIN/k3d"
fi

echo ""
echo "=== Installation Complete! ==="
echo ""

# Verify installations
echo "Verifying installations:"
echo "------------------------"

# We need to check with full path if command was just installed
if [ -f "$LOCAL_BIN/kubectl" ] || command_exists kubectl; then
    if [ -f "$LOCAL_BIN/kubectl" ]; then
        echo "✓ kubectl: $("$LOCAL_BIN/kubectl" version --client --short 2>/dev/null || echo "installed")"
    else
        echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null || echo "installed")"
    fi
else
    echo "✗ kubectl installation failed"
fi

if [ -f "$LOCAL_BIN/k3d" ] || command_exists k3d; then
    if [ -f "$LOCAL_BIN/k3d" ]; then
        echo "✓ k3d: $("$LOCAL_BIN/k3d" version | grep "k3d version" | head -1)"
    else
        echo "✓ k3d: $(k3d version | grep "k3d version" | head -1)"
    fi
else
    echo "✗ k3d installation failed"
fi

echo ""
echo "=== IMPORTANT: Next Steps ==="
echo ""
echo "1. Reload your shell to update PATH:"
echo "   source ~/.bashrc"
echo "   OR"
echo "   exec bash"
echo ""
echo "2. Verify the tools work:"
echo "   kubectl version --client"
echo "   k3d version"
echo ""
echo "3. Make sure you can access Docker:"
echo "   docker ps"
echo ""
echo "4. If Docker doesn't work, try:"
echo "   newgrp docker"
echo ""
echo "5. Then run the setup script:"
echo "   ./scripts/setup.sh"
echo ""
echo "Local binaries installed to: $LOCAL_BIN"