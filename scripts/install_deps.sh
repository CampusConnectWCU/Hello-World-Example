#!/bin/bash
#
# Hello World Cluster - Dependency Installation Script
# ===================================================
# This script demonstrates a complete node initialization process for Kubernetes deployment.
# It follows the same pattern as production CI/CD systems but simplified for learning.
#
# What this script does:
# 1. Installs Docker, Kubernetes tools (minikube, kubectl, helm, skaffold)
# 2. Creates a dedicated user with proper permissions
# 3. Sets up directory structure for logs and application deployment
# 4. Automatically starts the deployment process
#
# This script should be run as root or with sudo privileges.
# Run from anywhere: sudo ./cluster/scripts/install_deps.sh
#
set -e  # Exit immediately if any command fails

# --- Configuration Section ---
# These variables define the setup for our hello-world cluster
LOG_DIR="/local/logs"                    # Centralized logging directory
INSTALL_LOG="$LOG_DIR/install.log"       # Log file for this installation process
USERNAME="hellouser"                     # Dedicated user for running the cluster
USER_HOME="/home/$USERNAME"              # Home directory for the user
USER_TMPDIR="/var/tmp/hellouser-tmp"     # Temporary directory for user operations
REPO_DIR="/local/repository"             # Directory where application code will live

# Get the current script location to find the cluster directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_DIR="$(dirname "$SCRIPT_DIR")"

# --- Logging Setup ---
# Create a centralized logging system for all operations
echo "Setting up logging system..."
mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"
# Initially, root owns the install log for security
chown root:root "$INSTALL_LOG"
chmod 644 "$INSTALL_LOG"
# Redirect all script output (stdout & stderr) to the log file for debugging
exec > >(tee -a "$INSTALL_LOG") 2>&1

echo "=== Hello World Cluster Dependency Installation Started: $(date) ==="
echo "This script will set up a complete Kubernetes development environment"

# --- Core System Package Installation ---
echo ""
echo "Step 1: Installing core system packages..."
echo "Updating package list and installing essential tools..."
apt-get update
# Install core tools needed for containerization and networking
apt-get install -y docker.io socat curl git

# Verify Docker installation - Docker is essential for containerization
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker installation failed or 'docker' command not found."
    echo "Docker is required for running containers and building images."
    exit 1
fi
echo "✓ Docker installed successfully: $(docker --version)"

# --- User Account Setup ---
echo ""
echo "Step 2: Setting up dedicated user account for cluster operations..."
echo "Creating user '$USERNAME' with proper permissions for security..."

if ! id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' does not exist, creating new user..."
  # Create a user without password for automated operations
  adduser --disabled-password --gecos "" "$USERNAME"
  
  # Add user to docker group for container operations
  usermod -aG docker "$USERNAME"
  echo "  ✓ Added $USERNAME to docker group"
  
  # Add user to sudo group for administrative operations
  usermod -aG sudo "$USERNAME"
  echo "  ✓ Added $USERNAME to sudo group"
  
  # Grant passwordless sudo privileges for automated operations
  # This is common in cloud/container environments but should be used carefully
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
  chmod 0440 "/etc/sudoers.d/$USERNAME"  # Secure permissions for sudoers file
  echo "  ✓ Configured passwordless sudo for $USERNAME"

  # Set up PATH environment for the user
  echo 'export PATH=/usr/local/bin:$PATH' >> "$USER_HOME/.profile"
  echo 'export PATH=/usr/local/bin:$PATH' >> "$USER_HOME/.bashrc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.profile" "$USER_HOME/.bashrc"
  echo "  ✓ Configured PATH environment for $USERNAME"
  
else
  echo "User '$USERNAME' already exists, ensuring proper group membership..."
  # Ensure existing user has necessary group memberships
  if ! groups "$USERNAME" | grep -q '\bdocker\b'; then
    echo "  ✓ Adding existing user '$USERNAME' to docker group"
    usermod -aG docker "$USERNAME"
  fi
  if ! groups "$USERNAME" | grep -q '\bsudo\b'; then
    echo "  ✓ Adding existing user '$USERNAME' to sudo group"
    usermod -aG sudo "$USERNAME"
  fi
fi

# --- Directory Structure Setup ---
echo ""
echo "Step 3: Setting up directory structure for the cluster..."
echo "Creating organized directory layout for logs, code, and temporary files..."

# Temporary directory for user operations (with sticky bit for security)
mkdir -p "$USER_TMPDIR"
chown "$USERNAME:$USERNAME" "$USER_TMPDIR"
chmod 1777 "$USER_TMPDIR"  # Sticky bit (1777) allows users to create files but not delete others'
echo "  ✓ User temporary directory configured: $USER_TMPDIR"

# Repository directory where application code will be stored
mkdir -p "$REPO_DIR"
chown "$USERNAME:$USERNAME" "$REPO_DIR"
chmod 775 "$REPO_DIR"  # Allow user/group full access, others read-only
echo "  ✓ Repository directory configured: $REPO_DIR"

# Log directory setup with proper permissions
chown "$USERNAME:$USERNAME" "$LOG_DIR"  # User owns the main log directory
chmod 775 "$LOG_DIR"
# Create startup log file for the deployment process
touch "$LOG_DIR/startup.log"
chown "$USERNAME:$USERNAME" "$LOG_DIR/startup.log"
chmod 664 "$LOG_DIR/startup.log"  # User/group read/write, others read-only
echo "  ✓ Log directory permissions configured for user '$USERNAME'"

# --- Kubernetes Tools Installation ---
echo ""
echo "Step 4: Installing Kubernetes development tools..."
echo "These tools enable local Kubernetes development and deployment..."

# Install Minikube - Local single-node Kubernetes cluster
echo "Installing Minikube (local Kubernetes cluster)..."
MINIKUBE_URL="https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64"
curl -Lo minikube-linux-amd64 "$MINIKUBE_URL"
install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
# Verify Minikube installation
if ! command -v minikube &> /dev/null || ! [ -x "$(command -v minikube)" ]; then
    echo "ERROR: Minikube installation failed or command not executable!"
    echo "Minikube is required for running a local Kubernetes cluster."
    exit 1
fi
echo "  ✓ Minikube installed: $(minikube version --short)"

# Install Skaffold - Kubernetes development tool for building and deploying
echo "Installing Skaffold (Kubernetes development workflow tool)..."
SKAFFOLD_URL="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64"
curl -Lo skaffold "$SKAFFOLD_URL"
install skaffold /usr/local/bin/ && rm skaffold
# Verify Skaffold installation
if ! command -v skaffold &> /dev/null || ! [ -x "$(command -v skaffold)" ]; then
    echo "ERROR: Skaffold installation failed or command not executable!"
    echo "Skaffold is required for automated building and deployment."
    exit 1
fi
echo "  ✓ Skaffold installed: $(skaffold version)"

# Install kubectl - Kubernetes command-line tool
echo "Installing kubectl (Kubernetes command-line interface)..."
KUBECTL_STABLE=$(curl -sL https://dl.k8s.io/release/stable.txt)
KUBECTL_URL="https://dl.k8s.io/release/$KUBECTL_STABLE/bin/linux/amd64/kubectl"
curl -LO "$KUBECTL_URL"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
# Verify kubectl installation
if ! command -v kubectl &> /dev/null || ! [ -x "$(command -v kubectl)" ]; then
    echo "ERROR: kubectl installation failed or command not executable!"
    echo "kubectl is required for interacting with Kubernetes clusters."
    exit 1
fi
echo "  ✓ kubectl installed: $(kubectl version --client --short)"

# Install Helm - Kubernetes package manager
echo "Installing Helm (Kubernetes package manager)..."
HELM_SCRIPT_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
curl -fsSL -o get_helm.sh "$HELM_SCRIPT_URL"
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh
# Verify Helm installation
if ! command -v helm &> /dev/null || ! [ -x "$(command -v helm)" ]; then
    echo "ERROR: Helm installation failed or command not executable!"
    echo "Helm is required for managing Kubernetes applications."
    exit 1
fi
echo "  ✓ Helm installed: $(helm version --short)"

# --- Installation Complete ---
echo ""
echo "=== Hello World Cluster Dependency Installation Complete: $(date) ==="
echo "✓ User '$USERNAME' is configured with proper permissions"
echo "✓ All required tools are installed and verified"
echo "✓ Directory structure is set up for logging and deployment"

# --- Automatic Deployment Start ---
echo ""
echo "Step 5: Starting hello-world cluster deployment..."
echo "Now automatically copying cluster files and starting the deployment process..."

# Copy the entire cluster directory to the repository directory
# This ensures the deployment has access to all necessary files
echo "Copying cluster files to $REPO_DIR..."
cp -r "$CLUSTER_DIR"/* "$REPO_DIR/"
chown -R "$USERNAME:$USERNAME" "$REPO_DIR"
echo "  ✓ Cluster files copied to $REPO_DIR"

# Switch to the dedicated user and run the startup script
# This demonstrates the principle of least privilege - running as non-root user
echo "Executing startup script as $USERNAME (non-root user)..."
echo "The startup script will:"
echo "  - Start a local Kubernetes cluster (Minikube)"
echo "  - Configure ingress for external access"
echo "  - Set up port forwarding for the application"
echo "  - Deploy the hello-world application using Skaffold"
echo ""

su - "$USERNAME" -c "cd $REPO_DIR && ./scripts/startup.sh"

echo ""
echo "=== Installation and Deployment Complete ==="
echo "Your hello-world cluster should now be running!"
echo "Check the status with: kubectl get pods,svc,ingress" 