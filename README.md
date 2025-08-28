# Hello World Cluster - Cloudlab Example

A complete example of a Kubernetes cluster deployment that demonstrates the basic pattern for Cloudlab experiments. This repository shows how to create a simple Helm chart and use GitHub workflows to automate deployment.

## What This Repository Demonstrates

- **Basic Helm Chart**: Simple hello-world application with ingress
- **Node Initialization**: Automated dependency installation and setup
- **GitHub Workflow Integration**: Automated deployment via GitHub Actions
- **Cloudlab Automation**: Integration with the cloudlab-ci-cd repository

## Repository Structure

```
cluster/
├── helm/                    # Helm chart for the hello-world application
│   ├── Chart.yaml          # Chart metadata
│   ├── values.yaml         # Configuration values
│   └── templates/          # Kubernetes manifests
│       ├── frontend-deployment.yaml
│       ├── frontend-service.yaml
│       └── ingress.yaml
├── frontend/                # Application source code
│   ├── Dockerfile          # Container definition
│   ├── nginx.conf          # Web server configuration
│   └── index.html          # Hello world page
├── scripts/                 # Automation scripts
│   ├── install_deps.sh     # Dependency installation (run as root)
│   └── startup.sh          # Application deployment (run as hellouser)
├── .github/workflows/       # GitHub Actions workflows
│   └── deploy.yml          # Deployment workflow
├── profile.py              # Cloudlab profile definition
├── skaffold.yaml           # Skaffold configuration
└── README.md               # This file
```

## Quick Start

### Option 1: Manual Deployment (Local Development)

1. **Install dependencies** (run as root/sudo):
   ```bash
   sudo ./scripts/install_deps.sh
   ```

2. **The script automatically**:
   - Installs Docker, Minikube, Skaffold, kubectl, Helm
   - Creates `hellouser` with proper permissions
   - Sets up directory structure
   - Starts the deployment process

### Option 2: Automated Deployment (GitHub Workflows)

1. **Set up secrets** in your GitHub repository:
   - `CLOUDLAB_PEM`: Base64 encoded Cloudlab PEM file

2. **Push to main branch** or **create a pull request**:
   - The workflow automatically triggers
   - Calls the cloudlab-ci-cd automation
   - Deploys to Cloudlab

3. **Manual workflow dispatch**:
   - Go to Actions → Deploy to Cloudlab → Run workflow
   - Customize experiment name and node count

## GitHub Workflow Integration

This repository includes a GitHub workflow that integrates with the `cloudlab-ci-cd` automation repository:

```yaml
- name: Call Cloudlab CI/CD automation
  uses: your-org/cloudlab-ci-cd@main
  with:
    cloudlab_pem: ${{ secrets.CLOUDLAB_PEM }}
    profile_name: "hello-world-cluster"
    experiment_name: "hello-world-cluster-test"
    node_count: 1
    username: "ubuntu"
```

### Workflow Parameters

- **`cloudlab_pem`**: Your Cloudlab PEM file (stored as GitHub secret)
- **`profile_name`**: Name of this profile ("hello-world-cluster")
- **`experiment_name`**: Custom name for the Cloudlab experiment
- **`node_count`**: Number of nodes to provision
- **`username`**: SSH username for the nodes
- **`is_deployed`**: Skip initialization if nodes already exist

## How It Works

1. **GitHub workflow triggers** on push/PR to main branch
2. **Calls cloudlab-ci-cd automation** with your parameters
3. **Automation connects to Cloudlab** using your PEM file
4. **Runs the startup script** on the provisioned nodes
5. **Deploys hello-world application** using Skaffold and Helm

## Application Access

Once deployed, your hello-world application will be accessible at:
- **Primary URL**: `http://<hostname>` (if DNS is configured)
- **Alternative**: Use port-forward: `kubectl port-forward svc/hello-world-frontend-service 8080:80`

## Monitoring and Debugging

### Check Deployment Status
```bash
kubectl get pods,svc,ingress
```

### View Application Logs
```bash
kubectl logs -l app=hello-world-frontend
```

### Check Ingress Status
```bash
kubectl get ingress
```

### Access via Port Forward
```bash
kubectl port-forward svc/hello-world-frontend-service 8080:80
# Then open: http://localhost:8080
```

## Customization

### Modify the Application
- Edit `frontend/index.html` for content changes
- Modify `frontend/nginx.conf` for server configuration
- Update `helm/values.yaml` for deployment settings

### Add New Services
- Create new templates in `helm/templates/`
- Update `helm/values.yaml` with new configuration
- Modify `skaffold.yaml` if needed

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure you're running `install_deps.sh` as root/sudo
2. **Docker not accessible**: Log out and back in after running install script
3. **Startup script not found**: Check that the repository was copied to `/local/repository`
4. **Port forwarding fails**: Verify the service is running with `kubectl get svc`

### Logs Location
- **Installation logs**: `/local/logs/install.log`
- **Startup logs**: `/local/logs/startup.log`
- **Tunnel logs**: `/local/logs/tunnel.log`
- **Port forwarding logs**: `/local/logs/socat_80.log`

## Learning Objectives

This repository demonstrates:

- **Helm Chart Structure**: Basic Helm chart organization and templating
- **Kubernetes Deployment**: Pods, services, and ingress configuration
- **Containerization**: Docker images and multi-stage builds
- **Automation**: Script-based deployment and GitHub workflow integration
- **Cloudlab Integration**: Automated experiment provisioning and management
- **CI/CD Patterns**: Reusable automation components and workflow design

## Next Steps

1. **Customize the application** for your needs
2. **Add more services** to the Helm chart
3. **Integrate with your own repositories** using the workflow pattern
4. **Extend the automation** in the cloudlab-ci-cd repository

This example provides a solid foundation for building more complex Cloudlab experiments while maintaining the same automation patterns used in production CI/CD systems. 