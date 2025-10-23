[![ci](https://github.com/okdp/okdp-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/okdp/okdp-sandbox/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/okdp/okdp-sandbox)](https://github.com/okdp/okdp-sandbox/releases/latest)&ensp;&ensp;
[![Flux](https://img.shields.io/badge/flux-latest-purple.svg)](https://fluxcd.io/)
[![KuboCD](https://img.shields.io/badge/kubocd-v0.2.1-green.svg)](https://github.com/kubocd/kubocd)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Kind](https://img.shields.io/badge/kind-latest-orange.svg)](https://kind.sigs.k8s.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>

![OKDP UI Demo](https://raw.githubusercontent.com/OKDP/okdp-ui/main/docs/images/demo.gif)

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

### System Requirements

- **Minimum**: 16GB RAM and 4 CPUs
- **Docker/Podman allocation**: 8GB RAM and 2 CPUs minimum

### Software Dependencies

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Flux CLI](https://fluxcd.io/flux/installation/)


## Installation

### 1. Clone the Git Repository

```sh
git clone https://github.com/okdp/okdp-sandbox.git
cd okdp-sandbox
```

### 2. Create Kubernetes Kind Cluster

Create a Kind cluster configuration file and deploy the cluster:

> ℹ️ [Kind](https://kind.sigs.k8s.io/) is a tool for running local Kubernetes clusters using Docker.  
> It’s ideal for **development**, **testing**, and **sandbox reproducible environments**.  
> Kind follows a **manifest-first** (infrastructure-as-code) approach, while **Minikube** is a **command-line-first** approach.

```sh
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

# Create the cluster
kind create cluster --config /tmp/okdp-sandbox-config.yaml
```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

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

# Create the cluster
kind create cluster --config "$env:TEMP\okdp-sandbox-config.yaml"
```

</details>


### 3. Install Platform Components
#### Install Flux (GitOps engine)

> ℹ️ **[Flux](https://fluxcd.io/flux/concepts/)** is the GitOps controller that continuously reconciles your cluster state with what’s defined in Git.  
> The following command installs all Flux core components:
> - **source-controller**: fetches sources such as Git repositories and Helm charts  
> - **kustomize-controller**: applies Kubernetes manifests using Kustomize  
> - **helm-controller**: manages Helm releases declaratively  
> - **notification-controller**: handles alerts and automation triggers  
>
> 💡 In this setup, Flux controllers manage resources locally and are **not connected to a Git repository**.  
> Manifests are applied manually with `kubectl`, so **no Git access is required**.


```sh
flux install
```

#### Configure proxy settings for Flux controllers (Optional)

If your environment requires a proxy to reach external sources (container registries), the following command sets the proxy configuration variables to all Flux controllers (source, kustomize, helm, notification):

```sh
[ -n "${https_proxy}${HTTPS_PROXY}" ] && kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux \
        HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy}}" \
        HTTP_PROXY="${HTTP_PROXY:-${http_proxy}}" \
        NO_PROXY="${NO_PROXY:-${no_proxy}}"
```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

```powershell
if ($env:HTTPS_PROXY -or $env:https_proxy) {
    kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux `
        HTTPS_PROXY=($env:HTTPS_PROXY ?? $env:https_proxy) `
        HTTP_PROXY=($env:HTTP_PROXY ?? $env:http_proxy) `
        NO_PROXY=($env:NO_PROXY ?? $env:no_proxy)
}
```

</details>

Verify the proxy environment variables are correctly set for all Flux controllers:

> 💡 You may see the same variable (e.g., `HTTPS_PROXY`) repeated multiple times,
> one for each controller (**source**, **kustomize**, **helm**, **notification**).  
> This is expected and confirms that the variables were applied consistently.

```sh
kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux --list \
                                         | grep PROXY
```

> 💡 **Use the following command if you want to remove the proxy configuration from Flux controllers:**  
> After removing the proxy, Flux will **no longer be able to pull images or manifests from external registries** that require proxy access.
>
> ```sh
> kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux \
>    HTTPS_PROXY- \
>    NO_PROXY-
> ```

#### Wait for Flux controllers to be ready

Ensures all Flux controllers (source-controller, kustomize-controller, helm-controller, notification-controller) are fully running before proceeding to the next step:

```sh
kubectl wait --for=condition=ready pod -l app=source-controller -n flux-system --timeout=300s
```

#### Install KuboCD (Flux extension)

> ℹ️ [KuboCD](https://www.kubocd.io/) is the continuous delivery layer built on top of **Flux**.  
> It manages platform components and applications **declaratively**, providing a higher-level CD abstraction for GitOps workflows.

```sh
kubectl apply -f clusters/sandbox/flux/kubocd.yaml
```

#### Deploy OKDP platform components

Deploy the sandbox default context:

> 💡 **The KuboCD Context** is a centralized, declarative and environment-aware configuration layer that provides user defined shared variables (ingress suffixes, storage classes, certificate issuers, catalogs, and authentication settings, etc) to all the components, ensuring consistent deployment.
>
> During deployment, KuboCD automatically resolves and injects these context variables into the target Kubernetes components across the cluster (cluster-wide), ensuring that each component is deployed with a consistent configuration.


```sh
kubectl apply -f clusters/sandbox/default-context.yaml
```

> 💡 By default, the **default Context** uses **okdp.sandbox** as the ingress domain suffix.  
> This domain may be blocked if it does not comply with your organization’s allowed domain policy.  
>
> Use the following command to update the domain suffix to match your organization’s domain (replace **<CUSTOM_DOMAIN>** with your actual domain name):
>
> ```sh
> kubectl -n kubocd-system patch context default \
>   -p '{"spec":{"context":{"ingress":{"suffix":"<CUSTOM_DOMAIN>"}}}}' \
>   --type=merge
> ```


Deploy OKDP components:

```sh
kubectl apply -f clusters/sandbox/releases/addons
```

#### Verify and monitor release deployment status

Watch releases as they are deployed until all the components become ready.

```sh
kubectl get releases -A --watch
# Wait until all releases show STATUS=READY (press Ctrl+C to exit watch)
# Alternative: kubectl wait --for=condition=ready release --all --all-namespaces --timeout=600s
```

### 4. DNS Setup

Enable access to OKDP services through DNS resolution for the `okdp.sandbox` or your custom domain `<CUSTOM_DOMAIN>`:

- **Option 1 (Recommended)**: Local DNS server configuration (recommended, automatic for all services)
- **Option 2**: Manual `/etc/hosts` configuration (simple but requires manual updates)


📋 **See [dns-configuration.md](docs/dns-configuration.md) for detailed setup instructions for your operating system.**

### 5. SSL Certificate

For HTTPS access without warnings, two options:

**Option 1**: Install the CA certificate

```sh
# Import okdp-sandbox-ca.crt into your system's or browser's certificate store
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > okdp-sandbox-ca.crt
```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

```powershell
# Import okdp-sandbox-ca.crt into your system's or browser's certificate store
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } | Out-File -FilePath "okdp-sandbox-ca.crt" -Encoding ASCII
```

</details>

**Option 2**: Ignore certificate warnings
- **First, connect to Keycloak** (https://keycloak.okdp.sandbox or https://keycloak.<CUSTOM_DOMAIN>) and accept the self-signed certificate in your browser.
- This step is **mandatory** for all OKDP services (UI, MinIO, etc.) to communicate properly with Keycloak.

## Quick Start Guide

1. **Access OKDP UI**: https://okdp-ui.okdp.sandbox or https://okdp-ui.<CUSTOM_DOMAIN>
2. **Login credentials**: Default authentication via Keycloak (login/password: adm/adm)

## Cleanup

```bash
kind delete cluster --name okdp-sandbox
rm /tmp/okdp-sandbox-config.yaml
```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

```powershell
kind delete cluster --name okdp-sandbox
Remove-Item "$env:TEMP\okdp-sandbox-config.yaml" -Force
```

</details>

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
