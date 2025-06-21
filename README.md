<p align="center">
    <img width="400px" height=auto src="https://okdp.io/logos/okdp-inverted.png" />
</p>

# OKDP Sandbox

[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Flux](https://img.shields.io/badge/flux-2.4.0+-purple.svg)](https://fluxcd.io/)
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

```bash
# Clone the repository
git clone https://github.com/okdp/okdp-sandbox-draft.git
cd okdp-sandbox
```

### 2. Create Kubernetes Cluster

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

### 3. Install Platform Components

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
```


### 4. DNS Setup

Enable access to OKDP services through DNS resolution for the `okdp.sandbox` domain:

- **Option 1**: Manual `/etc/hosts` configuration (simple but requires manual updates)
- **Option 2**: Local DNS server configuration (recommended, automatic for all services)

📋 **See [dns-configuration.md](dns-configuration.md) for detailed setup instructions for your operating system.**

### 5. SSL Certificate

For HTTPS access without warnings, two options:

**Option 1**: Install the CA certificate
```bash
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > okdp-sandbox-ca.crt
# Import okdp-sandbox-ca.crt into your system's or browser's certificate store
```

**Option 2**: Ignore certificate warnings
- **First, connect to Keycloak** (https://keycloak.okdp.sandbox) and accept the self-signed certificate in your browser.
- This step is **mandatory** for all OKDP services (UI, MinIO, etc.) to communicate properly with Keycloak.

## Quick Start Guide

1. **Access OKDP UI**: https://okdp-ui.okdp.sandbox
2. **Login credentials**: Default authentication via Keycloak (login/password: adm/adm)


## Cleanup

```bash
kind delete cluster --name okdp-sandbox
rm /tmp/okdp-sandbox-config.yaml
```

---

**Built for the OKDP Community** 🚀
