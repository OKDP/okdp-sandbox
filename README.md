<p align="center">
    <img width="400px" height=auto src="https://okdp.io/logos/okdp-inverted.png" />
</p>

# OKDP Sandbox

[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Flux](https://img.shields.io/badge/flux-latest-purple.svg)](https://fluxcd.io/)
[![Kind](https://img.shields.io/badge/kind-latest-orange.svg)](https://kind.sigs.k8s.io/)
[![KuboCD](https://img.shields.io/badge/kubocd-v0.2.1-green.svg)](https://github.com/kubocd/kubocd)

A complete sandbox environment for testing and evaluating OKDP (Open Kubernetes Data Platform) components.

## What is OKDP Sandbox?

OKDP Sandbox provides a ready-to-use data platform environment that includes:
- Identity management (Keycloak)
- Object storage (MinIO)
- Data processing (Spark History Server)
- Notebooking (JupyterHub)
- Data visualization (Apache Superset)
- Platform management (OKDP Server & UI)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Flux CLI](https://fluxcd.io/flux/installation/)


## Installation

### 1. Clone the Repository

**Shell:**
```bash
# Clone the repository
git clone https://github.com/okdp/okdp-sandbox-draft.git
cd okdp-sandbox
```

**PowerShell:**
```powershell
# Clone the repository
git clone https://github.com/okdp/okdp-sandbox-draft.git
cd okdp-sandbox
```

### 2. Create Kubernetes Cluster

**Shell:**
```bash
# Create cluster configuration
cat > /tmp/okdp-sandbox-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
  - containerPort: 30443
    hostPort: 443
  - containerPort: 30053
    hostPort: 30053
    protocol: UDP
EOF

# Create cluster
kind create cluster --config /tmp/okdp-sandbox-config.yaml
```

**PowerShell:**
```powershell
# Create cluster configuration
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
  - containerPort: 30443
    hostPort: 443
  - containerPort: 30053
    hostPort: 53
    protocol: UDP
"@ | Out-File -FilePath "$env:TEMP\okdp-sandbox-config.yaml" -Encoding UTF8

# Create cluster
kind create cluster --config "$env:TEMP\okdp-sandbox-config.yaml"
```

### 3. Install Platform Components

**Shell:**
```bash
# Install Flux
flux install
kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s

# Optional: For proxy configuration, see https://fluxcd.io/flux/installation/configuration/proxy-setting/

# Install KuboCD
kubectl apply -f clusters/sandbox/flux/kubocd.yaml

# Deploy OKDP
kubectl apply -f clusters/sandbox/default-context.yaml
kubectl apply -f clusters/sandbox/releases/addons

# Wait for all releases to be deployed
kubectl get releases -A --watch
# Wait until all releases show STATUS=READY (press Ctrl+C to exit watch)
# Alternative: kubectl wait --for=condition=ready release --all --all-namespaces --timeout=600s
```

**PowerShell:**
```powershell
# Install Flux
flux install
kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s

# Optional: For proxy configuration, see https://fluxcd.io/flux/installation/configuration/proxy-setting/

# Install KuboCD
kubectl apply -f clusters/sandbox/flux/kubocd.yaml

# Deploy OKDP
kubectl apply -f clusters/sandbox/default-context.yaml
kubectl apply -f clusters/sandbox/releases/addons

# Wait for all releases to be deployed
kubectl get releases -A --watch
# Wait until all releases show STATUS=READY (press Ctrl+C to exit watch)
# Alternative: kubectl wait --for=condition=ready release --all --all-namespaces --timeout=600s
```

### 4. DNS Setup

Enable access to OKDP services through DNS resolution for the `okdp.sandbox` domain:

- **Option 1 (Recommended)**: Local DNS server configuration (recommended, automatic for all services)
- **Option 2**: Manual `/etc/hosts` configuration (simple but requires manual updates)


📋 **See [dns-configuration.md](docs/dns-configuration.md) for detailed setup instructions for your operating system.**

### 5. SSL Certificate

For HTTPS access without warnings, two options:

**Option 1**: Install the CA certificate

**Shell:**
```bash
# Import okdp-sandbox-ca.crt into your system's or browser's certificate store
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > okdp-sandbox-ca.crt
```

**PowerShell:**
```powershell
# Import okdp-sandbox-ca.crt into your system's or browser's certificate store
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } | Out-File -FilePath "okdp-sandbox-ca.crt" -Encoding ASCII
```

**Option 2**: Ignore certificate warnings
- **First, connect to Keycloak** (https://keycloak.okdp.sandbox) and accept the self-signed certificate in your browser.
- This step is **mandatory** for all OKDP services (UI, MinIO, etc.) to communicate properly with Keycloak.

## Quick Start Guide

1. **Access OKDP UI**: https://okdp-ui.okdp.sandbox
2. **Login credentials**: Default authentication via Keycloak (login/password: adm/adm)

## Cleanup

**Shell:**
```bash
kind delete cluster --name okdp-sandbox
rm /tmp/okdp-sandbox-config.yaml
```

**PowerShell:**
```powershell
kind delete cluster --name okdp-sandbox
Remove-Item "$env:TEMP\okdp-sandbox-config.yaml" -Force
```

---

**Built for the OKDP Community** 🚀