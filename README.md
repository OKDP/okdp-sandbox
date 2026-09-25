[![Flux](https://img.shields.io/badge/flux-latest-purple.svg)](https://fluxcd.io/)
[![KuboCD](https://img.shields.io/badge/kubocd-v0.3.2-green.svg)](https://github.com/kubocd/kubocd)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Kind](https://img.shields.io/badge/kind-latest-orange.svg)](https://kind.sigs.k8s.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)

OKDP Sandbox is a hands-on environment for deploying, testing, and exploring the [OKDP](https://okdp.io) ecosystem on a local Kubernetes cluster.

It deploys the platform foundations (identity, object storage, SQL, secrets, ingress) and the OKDP Control Plane on a local cluster. Data services (Spark jobs, notebooks, SQL querying, dashboards) are then instantiated per project through the Control Plane. See [What is included](#what-is-included-in-the-sandbox) for the full component list.

## What is included in the sandbox?

The default OKDP sandbox deploys the platform foundations and the Control Plane:

- Keycloak for identity and access management
- CloudNativePG and a PostgreSQL instance for SQL storage
- External Secrets for secret management
- Spark Operator for Spark workloads
- cert-manager and ingress-nginx for TLS and routing
- OKDP Control Plane (server and UI) for platform management

SeaweedFS (S3 object storage, needed by the data services, replaceable by any
S3-compatible backend such as RustFS) and Vault (secret backend) are optional
components: see
[clusters/sandbox/optional](clusters/sandbox/optional/README.md).

Data services (Airflow, JupyterHub, Trino, Hive Metastore, Superset, Spark
History Server) are not part of the sandbox deployment: they are instantiated
per project through the Control Plane.

## The three layers

The sandbox reads as three layers, each optional and building on the previous
one:

1. **The platform** (`clusters/sandbox/`): what the Quick start below deploys.
2. **The demo project** (`clusters/sandbox/project-demo/`): a complete project
   instance with its PostgreSQL, Connections and data services, the same shape
   the Control Plane deploys from the service catalog. See
   [its README](clusters/sandbox/project-demo/README.md).
3. **Example workloads** (`clusters/sandbox/project-demo/examples/`): the
   [okdp-examples](https://github.com/OKDP/okdp-examples) medallion lakehouse,
   seeded onto the demo project.

## Repository scope

This repository owns the **single-cluster sandbox deployment**. It describes how to deploy the OKDP platform onto a local Kubernetes cluster and contains the deployment assets only:

- `clusters/sandbox/flux/` : Flux bootstrap of the KuboCD controller (`kubocd.yaml`)
- `clusters/sandbox/releases/` : KuboCD `Release` manifests (what gets installed, which package tag, which parameters)
- `clusters/sandbox/contexts/` : the platform `Context` (in `okdp-system`, whose namespace is declared at the top of the file)
- `clusters/sandbox/contracts/` : the KuboCD `ClusterContract` files, applied before the contexts
- `clusters/sandbox/optional/` : components the platform can run on but does not need, applied by hand only, see [its README](clusters/sandbox/optional/README.md)
- `clusters/sandbox/project-demo/` : the demo project and its example workloads (layers 2 and 3), see [its README](clusters/sandbox/project-demo/README.md)
- `docs/` : deployment guides (DNS, certificates)

The **packages themselves** (the KuboCD packages bundled as OCI artifacts) live in dedicated repositories, split by ownership, OKDP core versus the third-party dependencies OKDP does not own and are consumed here from the registry. This repository never builds packages, it only deploys published ones.

| Concern | Owner |
|---|---|
| KuboCD packages for core services and control plane | [`OKDP/platform-packages`](https://github.com/OKDP/platform-packages) |
| KuboCD packages for third-party and bootstrap dependencies | [`OKDP/sandbox-dependencies`](https://github.com/OKDP/sandbox-dependencies) |
| Reusable utility Helm charts | [`OKDP/helm-charts-utilities`](https://github.com/OKDP/helm-charts-utilities) |
| Notebooks, DAGs, and runnable examples | [`OKDP/okdp-examples`](https://github.com/OKDP/okdp-examples) |
| Control Plane web UI | [`OKDP/okdp-control-plane-ui`](https://github.com/OKDP/okdp-control-plane-ui) |
| Control Plane backend server (API) | [`OKDP/okdp-control-plane-server`](https://github.com/OKDP/okdp-control-plane-server) |
| Single-cluster sandbox deployment (this repository) | `OKDP/okdp-sandbox` |

## Prerequisites

### System requirements

- Minimum: 16 GB RAM and 4 CPUs
- Docker or Podman allocation: at least 8 GB RAM and 2 CPUs

### Software dependencies

- [Docker](https://docs.docker.com/get-docker/) or a compatible container runtime
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Flux CLI v2.7.5](https://fluxcd.io/flux/installation/)
- [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli)
- [Helm](https://helm.sh/docs/intro/install/) 

## Quick start

The sandbox deployment files live in this repository under `clusters/sandbox/`.

### 1. Clone this repository

```sh
git clone https://github.com/OKDP/okdp-sandbox.git
cd okdp-sandbox
```

### 2. Create Kubernetes Kind Cluster

Create a Kind cluster configuration file and deploy the cluster:

> <details>
> <summary>ℹ️ <strong>Why Kind?</strong></summary>
> 
> [Kind](https://kind.sigs.k8s.io/) is a tool for running local Kubernetes clusters using Docker.  
> It’s ideal for **development**, **testing**, and **sandbox reproducible environments**.  
> Kind follows a **manifest-first** (infrastructure-as-code) approach, while **Minikube** is a **command-line-first** approach.
> </details>

```sh
# Create cluster configuration
cat > /tmp/okdp-sandbox-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
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
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
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

### 3. Install Cilium (CNI)

Until Cilium is installed, the cluster has no Pod networking. `kubectl get nodes` reports `NotReady` and this is expected. Installing Cilium brings networking into the cluster.

Make sure to install Cilium before Flux as they need networking to start.
Cilium also replaces **kube-proxy** for service exposure.

To install Cilium:

```sh
# Cilium needs the API server address because kube-proxy is disabled.
CLUSTER=okdp-sandbox # result of "kind get clusters" command
NODE=$(kind get nodes --name "$CLUSTER" | grep -m1 control-plane)
CP_IP=$(docker inspect "$NODE" -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "control-plane IP: $CP_IP" # must be non-empty before you continue

helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update cilium
helm upgrade --install cilium cilium/cilium --version 1.19.6 \
  --namespace kube-system \
  -f clusters/sandbox/cilium/values.yaml \
  --set k8sServiceHost="$CP_IP" --set k8sServicePort=6443

# Wait for the datapath to come up
kubectl -n kube-system rollout status ds/cilium --timeout=180s

```

### 4. Install Platform Components
#### Install Flux (GitOps engine)

> ℹ️ Note
>
> This step is only required for a fresh installation. If Flux is already installed and running, you do not need to install it again.  
> For upgrades, go directly to [Deploy/Upgrade OKDP platform components](#deployupgrade-okdp-platform-components).
> 

> <details>
> <summary>ℹ️ <strong>What is Flux and how is it used here?</strong></summary>
>
> **[Flux](https://fluxcd.io/flux/concepts/)** is the GitOps controller that continuously reconciles your cluster state with what’s defined in Git.  
> The following command installs all Flux core components:
> - **source-controller**: fetches sources such as Git repositories and Helm charts
> - **kustomize-controller**: applies Kubernetes manifests using Kustomize
> - **helm-controller**: manages Helm releases declaratively
> - **notification-controller**: handles alerts and automation triggers
>
>  In this setup, Flux controllers manage resources locally and are **not connected to a Git repository**.  
> Manifests are applied manually with `kubectl`, so **no Git access is required**.
> </details>

```sh
flux install
```

##### Configure proxy settings for Flux controllers (Optional):

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

##### Verify the proxy environment variables are correctly set for all Flux controllers (Optional):

```sh
kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux --list \
                                         | grep PROXY
```

> 💡 You may see the same variable (e.g., `HTTPS_PROXY`) repeated multiple times,
> one for each controller (**source**, **kustomize**, **helm**, **notification**).  
> This is expected and confirms that the variables were applied consistently.


> <details>
> <summary>💡 <strong>How to remove the Flux proxy configuration?</strong></summary>
>
> **Use the following command if you want to remove the proxy configuration from Flux controllers:**  
> After removing the proxy, Flux will **no longer be able to pull images or manifests from external registries** that require proxy access.
>
> ```sh
> kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux \
>    HTTPS_PROXY- \
>    NO_PROXY-
> ```
> </details>

##### Wait for Flux controllers to be ready

Ensures all Flux controllers (source-controller, kustomize-controller, helm-controller, notification-controller) are fully running before proceeding to the next step:

```sh
kubectl -n flux-system wait --for=condition=Available deploy \
  -l app.kubernetes.io/part-of=flux --timeout=300s
```

#### Install KuboCD (Flux extension)
> <details>
> <summary>ℹ️ <strong>What is KuboCD?</strong></summary>
>
> ℹ️ [KuboCD](https://www.kubocd.io/) is the continuous delivery layer built on top of **Flux**.  
> It manages platform components and applications **declaratively**, providing a higher-level CD abstraction for GitOps workflows.
> </details>

```sh
kubectl apply -f clusters/sandbox/flux/kubocd.yaml
```

##### Wait for KuboCD to be installed before continuing:

1. Wait for Flux to finish installing KuboCD chart:

```sh
kubectl -n flux-system wait --for=condition=Ready helmrelease/kubocd-controller --timeout=300s
```

2. Wait for KuboCD CRDs to be registered:

```sh
kubectl wait --for=condition=Established --timeout=300s \
  crd/contexts.kubocd.kubotal.io \
  crd/releases.kubocd.kubotal.io \
  crd/configs.kubocd.kubotal.io \
  crd/clustercontracts.kubocd.kubotal.io \
  crd/connections.kubocd.kubotal.io
```

3. Wait for KuboCD controller to be up:

```sh
kubectl -n kubocd wait --for=condition=Available deploy/kubocd-ctrl-controller --timeout=300s
```

#### Install metrics-server

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
       {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/timeoutSeconds", "value": 3},
       {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/timeoutSeconds", "value": 3}]'
```

> The default probe timeout of 1s is too tight for a single-node kind cluster: under
> load the probes fail and the pod is restarted with a new IP, which the API server
> keeps NATing to the old one.

##### Wait for metrics-server to be ready:

1. Wait for the patched pod to roll out:

```sh
kubectl -n kube-system rollout status deploy/metrics-server --timeout=300s
```

2. Wait for the metrics API to be served:

```sh
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=300s
```

3. Verify it's working:

```sh
kubectl top nodes
```

> 💡 `kubectl top nodes` may still report `metrics not available yet` for a few seconds
> after the API becomes available, until the first scrape completes. Re-run it if so.

#### Deploy/Upgrade OKDP platform components

> 💡 **Upgrade note**  
> To upgrade the OKDP platform components, run:
>
> ```bash
> kubectl delete $(kubectl get release -n kubocd-system -o name) -n kubocd-system
> ```
>
> This will delete all KuboCD `Release` resources in the `kubocd-system` namespace.
>
> During upgrade command, you may see errors like:
>
> ```
> Error from server (Forbidden): admission webhook "vrelease-v1alpha1.kb.io" denied the request: release cert-manager is protected
> Error from server (Forbidden): admission webhook "vrelease-v1alpha1.kb.io" denied the request: release kubocd-webhooks is protected
> ```
>
> These errors can be safely ignored. The affected releases are **system-protected components** managed by the platform and have a **separate upgrade lifecycle**.
>
> Pull the latest updates locally before starting the upgrade.
> 
> ```bash
> git pull --rebase
> ```
>


##### Deploy/Upgrade the sandbox default context:

> <details>
> <summary>ℹ️ <strong>What is KuboCD Context?</strong></summary>
>
> **KuboCD Context** is a centralized, reusable, declarative and environment-aware configuration layer that provides user defined shared parameters (ingress suffixes, storage classes, certificate issuers, catalogs, and authentication settings, etc) to all the components, ensuring consistent deployment.
>
> During deployment, KuboCD automatically resolves and injects these context variables into the target Kubernetes components across the cluster (cluster-wide), ensuring that every component is deployed with a consistent configuration.
>
> During a Context update, changes are automatically propagated only to the affected components, which are then reconciled to align with the desired configuration.
> 
> For example, the **Context** enables defining **different configurations for different environments**:
> - `sandbox` for experimentation
> - `dev` for internal testing  
> - `prod` for stable production environments 
> - `org` (or `global`) for the organization-wide configuration that provides defaults to other environments.
>
> Each environment can **define, override or extend** one or more contexts while preserving a unified, declarative deployment model.
> </details>


```sh
kubectl apply -f clusters/sandbox/contracts/
kubectl apply --server-side -f clusters/sandbox/contexts/
```

##### Configure a custom ingress domain for OKDP Services (Optional)

> 💡 By default, the **default Context** uses **okdp.sandbox** as the ingress domain suffix.  
> This domain may be blocked if it does not comply with your organization’s allowed domain policy.  
>
> Use the following command to update the domain suffix to match your organization’s domain (replace **<CUSTOM_DOMAIN>** with your actual domain name):
>
> ```sh
> kubectl -n okdp-system patch context platform --type=merge -p '{
>   "spec": { "context": {
>     "ingress": { "suffix": "<CUSTOM_DOMAIN>" },
>     "oidc": {
>       "issuerUri":   "https://keycloak.<CUSTOM_DOMAIN>/realms/master",
>       "authUrl":     "https://keycloak.<CUSTOM_DOMAIN>/realms/master/protocol/openid-connect/auth",
>       "tokenUrl":    "https://keycloak.<CUSTOM_DOMAIN>/realms/master/protocol/openid-connect/token",
>       "jwksUri":     "https://keycloak.<CUSTOM_DOMAIN>/realms/master/protocol/openid-connect/certs",
>       "userinfoUrl": "https://keycloak.<CUSTOM_DOMAIN>/realms/master/protocol/openid-connect/userinfo"
>     }
>   } }
> }'
> ```
>
> The OIDC endpoints carry the domain too. Patching the suffix alone moves the
> Keycloak route while the services keep validating tokens against the old host.

##### Configure proxy settings for OKDP Services (Optional)

> 💡 If your environment requires a proxy to reach external datasets (Superset examples, okdp examples, quay.io KuboCD packages), the following command sets the proxy configuration variables to the required OKDP services:
>
> ```sh
> kubectl -n okdp-system patch context platform --type merge -p "$(cat <<EOF
> spec:
>   context:
>     proxy:
>       httpProxy: "${HTTP_PROXY:-${http_proxy}}"
>       httpsProxy: "${HTTPS_PROXY:-${https_proxy}}"
>       noProxy: "${NO_PROXY:-${no_proxy}}"
> EOF
> )"
> ```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

```powershell
kubectl -n okdp-system patch context platform --type merge -p @"
spec:
  context:
    proxy:
        httpProxy: "$($env:HTTP_PROXY ?? $env:http_proxy)"
        httpsProxy: "$($env:HTTPS_PROXY ?? $env:https_proxy)"
        noProxy: "$($env:NO_PROXY ?? $env:no_proxy)"
"@
```
</details>

##### Deploy/Upgrade OKDP components:

```sh
kubectl apply -f clusters/sandbox/releases/
```

> ℹ️ **Installing optional components:**
> 
> The directory [clusters/sandbox/optional](clusters/sandbox/optional) is deliberately excluded from that apply. It contains components that are supported by the platform but are not required, including KubAuth, SeaweedFS, and HashiCorp Vault.  
> To install an optional component, see [clusters/sandbox/optional/README.md](clusters/sandbox/optional/README.md) for its purpose and configuration.

##### Verify and monitor release deployment status

Watch releases as they are deployed until all the components become ready.

```sh
kubectl get releases -A --watch
```

Or block until every release is ready instead of watching:

```sh
kubectl wait --for=jsonpath='{.status.phase}'=READY release --all -n kubocd-system --timeout=900s
```

### 5. DNS Setup

Enable access to OKDP services through DNS resolution for the `okdp.sandbox` or your custom domain `<CUSTOM_DOMAIN>`:

- **Option 1 (Recommended)**: Local DNS server configuration (recommended, automatic for all services)
- **Option 2**: Manual `/etc/hosts` configuration (simple but requires manual updates)


📋 **See [dns-configuration.md](docs/dns-configuration.md) for detailed setup instructions for your operating system.**

### 6. SSL Certificate

For HTTPS access without warnings, two options:

**Option 1**: Install the CA certificate

The sandbox uses a local certificate authority.

To avoid browser warnings, export the generated CA certificate and import it into your system or browser trust store:

```sh
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
- This step is **mandatory** for all OKDP services (UI, object storage, etc.) to communicate properly with Keycloak.

## Quick Start Guide

1. **Access OKDP UI**: https://okdp-ui.okdp.sandbox or https://okdp-ui.<CUSTOM_DOMAIN>
2. **Login credentials**: Default authentication via Keycloak (login/password: adm/adm)
3. **Deploy the demo project**: Follow the [demo project guide](clusters/sandbox/project-demo/README.md) to provision the demo project using kubectl (namespace, storage, database, connections, and data services).
   > **ℹ️ Note:** A project can also be provisioned directly through the OKDP UI instead of using `kubectl`.
4. **Run the examples**: Once the demo project is ready, follow [OKDP examples guide](https://github.com/OKDP/okdp-examples) to run the examples.

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

## License

This project is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
