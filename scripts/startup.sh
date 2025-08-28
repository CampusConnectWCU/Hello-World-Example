#!/bin/bash
#
# Hello World Cluster - Startup and Deployment Script
# ===================================================
# This script demonstrates the complete deployment process for a Kubernetes application.
# It follows the same pattern as production CI/CD systems but simplified for learning.
#
# What this script does:
# 1. Starts a local Kubernetes cluster (Minikube)
# 2. Configures ingress controller for external access
# 3. Sets up network port forwarding for the application
# 4. Deploys the hello-world application using Skaffold
#
# This script runs as 'hellouser' (non-root user) for security best practices.
# It's automatically called by install_deps.sh after dependency installation.
#
set -e  # Exit immediately if any command fails

# --- Configuration & Logging Section ---
# Centralized logging system for all deployment operations
LOG_DIR="/local/logs"                    # Centralized logging directory
STARTUP_LOG="$LOG_DIR/startup.log"       # Log file for this deployment process
TUNNEL_LOG="$LOG_DIR/tunnel.log"         # Log file for minikube tunnel operations
SOCAT_80_LOG="$LOG_DIR/socat_80.log"     # Log file for port forwarding operations
REPO_DIR="/local/repository"             # Directory containing application code
HELM_DIR="$REPO_DIR/helm"                # Directory containing Helm charts

# Redirect all script output (stdout & stderr) to the startup log file
# This provides a complete audit trail of the deployment process
exec > >(tee -a "$STARTUP_LOG") 2>&1

echo "=== Hello World Cluster Startup Script Started: $(date) ==="
echo "User: $(whoami)"
echo "Current Directory: $(pwd)"
echo "Initial PATH: $PATH"
echo "This script will deploy a complete hello-world application to Kubernetes"

# --- Minikube Cluster Initialization ---
echo ""
echo "Step 1: Starting local Kubernetes cluster..."
echo "Minikube provides a single-node Kubernetes cluster for local development"

echo "Starting Minikube cluster with Docker driver..."
# Docker driver is preferred for Linux systems as it provides better performance
# and doesn't require additional virtualization software
minikube start --driver=docker

echo "Enabling Minikube Ingress addon..."
# The ingress addon provides an NGINX ingress controller
# This allows external traffic to reach applications inside the cluster
minikube addons enable ingress

echo "Configuring ingress-nginx service for external access..."
# Patch the ingress-nginx service to use LoadBalancer type
# This allows the ingress controller to receive external traffic
# The default ClusterIP type only allows internal cluster access
kubectl patch svc ingress-nginx-controller \
  -n ingress-nginx \
  -p '{"spec": {"type": "LoadBalancer"}}' \

echo "Waiting for ingress-nginx controller to become ready..."
# Wait for the ingress controller pod to be fully ready
# This ensures the ingress system is operational before proceeding
# The timeout prevents infinite waiting if something goes wrong
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# --- Network Configuration and Port Forwarding ---
echo ""
echo "Step 2: Setting up network access and port forwarding..."
echo "This enables external access to the application running in the cluster"

echo "Starting Minikube tunnel in background..."
# Minikube tunnel creates a route to the LoadBalancer service
# This allows external traffic to reach the ingress controller
# The tunnel runs in the background and forwards traffic automatically
nohup sudo minikube tunnel > "$TUNNEL_LOG" 2>&1 &
# Allow time for the tunnel process to establish connection
sleep 5

echo "Setting up port forwarding for HTTP access..."
# Socat forwards traffic from host port 80 to the ingress controller
# Port 80 is the standard HTTP port for web traffic
# 192.168.49.2 is typically the IP address assigned to the ingress service
echo "Forwarding host port 80 to ingress controller (192.168.49.2:80)..."
setsid sudo socat TCP-LISTEN:80,fork TCP:192.168.49.2:80 </dev/null &>> "$SOCAT_80_LOG" &

echo "Retrieving Minikube cluster IP address..."
# Get the IP address of the Minikube cluster
# This is used for verification and potential additional port forwarding
MINIKUBE_IP=$(minikube ip)
if [ -z "$MINIKUBE_IP" ]; then
  echo "ERROR: Failed to retrieve Minikube IP using 'minikube ip'."
  echo "This indicates the cluster may not be running properly."
  exit 1
fi
echo "✓ Minikube cluster IP: $MINIKUBE_IP"

# --- Docker Environment Configuration ---
echo ""
echo "Step 3: Configuring Docker environment for the cluster..."
echo "Setting Docker to use Minikube's Docker daemon for image building"

echo "Configuring shell to use Minikube's Docker daemon..."
# Minikube runs its own Docker daemon for building and storing images
# This ensures images are available to the Kubernetes cluster
eval $(minikube docker-env)

# Verify the Docker context is properly set to Minikube
docker info | grep -i "kubernetes.*minikube" || echo "WARNING: Docker context might not be set to Minikube."

# --- Temporary Directory Setup ---
echo ""
echo "Step 4: Configuring temporary directory for operations..."
echo "Setting up secure temporary storage for the deployment process"

# Ensure TMPDIR is set and writable (configured by install_deps.sh)
export TMPDIR=/var/tmp/hellouser-tmp
if [ ! -d "$TMPDIR" ] || ! touch "$TMPDIR/.writable_test" 2>/dev/null; then
    echo "ERROR: TMPDIR ($TMPDIR) is not writable or does not exist."
    echo "This suggests the install_deps.sh script was not run properly."
    
    # Attempt to recover by recreating the directory with proper permissions
    echo "Attempting to fix TMPDIR permissions..."
    sudo mkdir -p "$TMPDIR" && sudo chown "$(whoami):$(whoami)" "$TMPDIR" && sudo chmod 1777 "$TMPDIR"
    
    if ! touch "$TMPDIR/.writable_test" 2>/dev/null; then
        echo "ERROR: Failed to fix TMPDIR permissions."
        echo "Please run install_deps.sh as root to fix this issue."
        exit 1
    fi
fi
rm -f "$TMPDIR/.writable_test"
echo "✓ TMPDIR configured and accessible: $TMPDIR"

# --- Application Deployment ---
echo ""
echo "Step 5: Deploying the hello-world application..."
echo "Now deploying the application using Skaffold for automated workflow"

echo "Changing to repository directory: $REPO_DIR"
# Navigate to the directory containing the application code
# This is where Skaffold will find the configuration files
cd "$REPO_DIR" || { 
    echo "ERROR: Failed to access repository directory: $REPO_DIR"
    echo "This suggests the install_deps.sh script did not complete properly."
    exit 1 
}

echo "Deploying hello-world application using Skaffold..."
# Skaffold automates the entire deployment process:
# 1. Builds the Docker image from the Dockerfile
# 2. Deploys the Helm chart to Kubernetes
# 3. Sets up services, deployments, and ingress
# 4. Monitors the deployment for success
skaffold run

# --- Deployment Complete ---
echo ""
echo "=== Hello World Cluster Deployment Complete ==="
echo "Your application has been successfully deployed to Kubernetes!"

# Get the hostname for access information
HOSTNAME=$(hostname -f)  # Get the fully qualified domain name

echo ""
echo "Application Access Information:"
echo "  Primary URL: http://$HOSTNAME"
echo "  Note: If $HOSTNAME is not resolvable externally, use localhost:80"
echo ""

echo "Useful Commands for Monitoring:"
echo "  Check deployment status:"
echo "    kubectl get pods,svc,ingress"
echo ""
echo "  Access application via port-forward (alternative method):"
echo "    kubectl port-forward svc/hello-world-frontend-service 8080:80"
echo "    Then open: http://localhost:8080"
echo ""
echo "  View application logs:"
echo "    kubectl logs -l app=hello-world-frontend"
echo ""
echo "  Check ingress status:"
echo "    kubectl get ingress"
echo ""

echo "Startup script finished successfully at $(date)"
echo "Your hello-world cluster is now running and accessible!" 