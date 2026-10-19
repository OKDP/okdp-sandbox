[![Flux](https://img.shields.io/badge/flux-v2.9-purple.svg)](https://fluxcd.io/)
[![Argo CD](https://img.shields.io/badge/argo%20cd-v3.4-orange.svg)](https://argo-cd.readthedocs.io/)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.30+-blue.svg)](https://kubernetes.io/)
[![Kind](https://img.shields.io/badge/kind-latest-orange.svg)](https://kind.sigs.k8s.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)

OKDP Sandbox is a hands-on environment for deploying, testing, and exploring the [OKDP](https://okdp.io) ecosystem on a local Kubernetes cluster.

It deploys the platform foundations (identity, object storage, SQL, secrets, ingress), the OKDP Control Plane and a demo project on a local cluster, from a Git repository, with **Flux or Argo CD**: pick one, the repository is the same. Data services (Spark jobs, notebooks, SQL querying, dashboards) are then instantiated per project through the Control Plane, or by writing the same files in Git.

## Security notice

The sandbox is for a single workstation, not a shared or reachable environment:

- It ships **published demo credentials**: Keycloak admin `admin` / `admin`, console user
  `adm` / `adm` (and the other demo users and client secrets of
  [`20-keycloak`](gitops/platform/components/20-keycloak/values.yaml)), and, with the
  optional Vault, the dev-mode root token `root`. Never reuse them, and never reuse these
  values outside the sandbox.
- The Forgejo credentials are generated on your cluster, never committed: the admin's
  (step 3), and those of `okdp-gitops`, the account the console and the CI write to the
  deployments repositories with (not an admin; its Secret exists only in the namespaces
  of the console and of the CI runner). Whoever can push to the deployments
  repositories still controls the cluster.
- **Do not expose it beyond localhost.** The kind port mappings below listen on
  `127.0.0.1` only; keep it that way (no `0.0.0.0`, no port forwarding from other hosts).
- The sandbox CA can issue a certificate for any name. If you trust it (step 6),
  **remove it from your trust store after use** (see
  [install-certificate.md](docs/install-certificate.md#removing-the-certificate)).

## What is included in the sandbox?

The platform ([`gitops/platform/components`](gitops/platform/components), one directory per component, deployed in layers):

| Layer | Components |
|---|---|
| `00` CRDs and operators | tools (Reloader, replicator, deletion protection), cert-manager, CloudNativePG, External Secrets, Spark Operator |
| `10` infrastructure | ingress-nginx, cluster issuers and trust-manager, CoreDNS patch, DNS server, local secrets provider, Spark RBAC |
| `20` identity, storage, databases | Keycloak and its PostgreSQL, RustFS or SeaweedFS (S3), **Forgejo** (the deployments repositories and the service catalogs), the CA trust bundle |
| `30` control plane | OKDP Control Plane server and UI |

The demo project ([`gitops/projects/demo`](gitops/projects/demo)): a PostgreSQL, the S3 store and the data services Hive Metastore, Polaris, Trino, Superset, Airflow, JupyterHub and Spark History Server, wired together by the outputs they publish (the PostgreSQL databases) and connection files (the platform's S3 store).

Optional ([`gitops/optional`](gitops/optional)): Vault (a secret backend), and the [okdp-examples](https://github.com/OKDP/okdp-examples) medallion lakehouse seed for the demo project.

## How it works

```
basic user ─► console UI ─► control-plane server ─(git commit)─┐
GitOps user ────────────────────────────(git commit / PR)────► sources: platform/, projects/ (Forgejo)
                                                               │ each push: the CI (Forgejo Actions)
   service catalogs (Git) ─► packages ─► okdp-gitops compile (okdp-compiler), runner 30-forgejo-runner
                                                               ▼
                         output: compiled/ (one umbrella chart and values file per instance), flux/, argocd/
                  Flux: HelmRelease (chart from Git) │ Argo CD: Application (path + values file)
                                                               ▼
                    Helm installs the SAME umbrella chart with the SAME compiled values
```

- Every component and service is an instance of a package of the service catalogs (or an upstream chart) with its values in Git: [`gitops/`](gitops) is the initial deployments layout, the sources and the entry points of the engines. Its [README](gitops/README.md) specifies every file.
- Git, on the in-cluster Forgejo, is the only desired state. The console commits the sources there; so can you, a plain commit. Each instance is compiled ([okdp-compiler](https://github.com/OKDP/okdp-compiler)) into an umbrella chart over the upstream charts of its service and the one values file it is installed with, `compiled/` of the output repository, by [okdp-gitops](https://github.com/OKDP/okdp-gitops), which also writes the Flux and Argo CD files and their order: by the CI on each push to the sources (the workflow `.forgejo/workflows/okdp-gitops.yaml` of each repository of the sources, run by the Forgejo Actions runner [`30-forgejo-runner`](gitops/platform/components/30-forgejo-runner)), and by `scripts/configure.sh --push` for the layout of this repository, which it pushes compiled (the bootstrap: the runner is deployed from the output). A push that does not compile writes nothing: the engine keeps deploying the last output. Flux or Argo CD deploys `compiled/`. This repository holds no compiled file: only what bootstraps the sandbox.
- On Forgejo, the layout lives in one deployments repository, `okdp-deployments` (`mono`), in an input and an output repository (`io`), or in a platform repository, one repository per project and an output repository (`split`): the **topology**, chosen with `scripts/configure.sh` ([Topologies](gitops/README.md#topologies)). Flux and Argo CD read the output repository only.
- The packages come from Git, not from a chart registry: the catalogs [platform-charts](https://github.com/OKDP/platform-charts) and [sandbox-dependencies](https://github.com/OKDP/sandbox-dependencies) (`catalog/<service>/<version>/`, one directory per package version, and the contracts of the connections), copied to the in-cluster Forgejo, where the control plane server reads them ([Service catalogs](gitops/README.md#service-catalogs)). The upstream charts come from their own repositories.

| Concern | Owner |
|---|---|
| Catalog of the OKDP services and control plane packages | [`OKDP/platform-charts`](https://github.com/OKDP/platform-charts) |
| Compiler of the instances (service definitions in YAML + CEL) | [`OKDP/okdp-compiler`](https://github.com/OKDP/okdp-compiler) |
| Compile of the whole layout, the Flux and Argo CD files, the CI of the sources | [`OKDP/okdp-gitops`](https://github.com/OKDP/okdp-gitops) |
| Contract schemas of the connections | the catalogs, `contracts/` |
| Catalog of the third-party and bootstrap packages | [`OKDP/sandbox-dependencies`](https://github.com/OKDP/sandbox-dependencies) |
| Notebooks, DAGs, and runnable examples | [`OKDP/okdp-examples`](https://github.com/OKDP/okdp-examples) |
| Control Plane web UI | [`OKDP/okdp-control-plane-ui`](https://github.com/OKDP/okdp-control-plane-ui) |
| Control Plane backend server (API) | [`OKDP/okdp-control-plane-server`](https://github.com/OKDP/okdp-control-plane-server) |
| Sandbox bootstrap: the initial deployments layout and its scripts (this repository) | `OKDP/okdp-sandbox` |

## Prerequisites

- 16 GB RAM and 4 CPUs at least for the platform; the whole demo project needs about 32 GB.
- [Docker](https://docs.docker.com/get-docker/) or a compatible container runtime, [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation), [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), [Helm](https://helm.sh/docs/intro/install/) and `git`.
- For Flux: the [Flux CLI](https://fluxcd.io/flux/installation/) (tested with v2.9.5). For Argo CD: nothing more (tested with v3.4.2).
- To configure the sandbox and change the layout by hand: `okdp-gitops` ([okdp-gitops](https://github.com/OKDP/okdp-gitops), `make build`), [yq](https://github.com/mikefarah/yq) v4, `curl` and `jq`. The scripts read the service catalogs from checkouts of [platform-charts](https://github.com/OKDP/platform-charts) and [sandbox-dependencies](https://github.com/OKDP/sandbox-dependencies) next to this repository when there are some (at the ref [`catalog.yaml`](gitops/platform/catalog.yaml) names), else from GitHub.

## Quick start

### 1. Clone this repository

```sh
git clone https://github.com/OKDP/okdp-sandbox.git
cd okdp-sandbox
```

### 2. Create the kind cluster

```sh
cat > /tmp/okdp-sandbox-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
# TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    listenAddress: "127.0.0.1"
  - containerPort: 30443
    hostPort: 443
    listenAddress: "127.0.0.1"
  - containerPort: 30053
    hostPort: 30053
    listenAddress: "127.0.0.1"
    protocol: UDP
EOF
kind create cluster --config /tmp/okdp-sandbox-config.yaml
# TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
# The control plane images come from repo.alliage.io:8082, over plain HTTP.
docker exec okdp-sandbox-control-plane mkdir -p /etc/containerd/certs.d/repo.alliage.io:8082
docker exec -i okdp-sandbox-control-plane tee /etc/containerd/certs.d/repo.alliage.io:8082/hosts.toml >/dev/null <<EOF
server = "http://repo.alliage.io:8082"
[host."http://repo.alliage.io:8082"]
  capabilities = ["pull", "resolve"]
EOF
```

<details>
<summary><strong><small>PowerShell</small></strong></summary>
<br>

```powershell
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
# TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    listenAddress: "127.0.0.1"
  - containerPort: 30443
    hostPort: 443
    listenAddress: "127.0.0.1"
  - containerPort: 30053
    hostPort: 53
    listenAddress: "127.0.0.1"
    protocol: UDP
"@ | Out-File -FilePath "$env:TEMP\okdp-sandbox-config.yaml" -Encoding UTF8
kind create cluster --config "$env:TEMP\okdp-sandbox-config.yaml"
# TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
# The control plane images come from repo.alliage.io:8082, over plain HTTP.
docker exec okdp-sandbox-control-plane mkdir -p /etc/containerd/certs.d/repo.alliage.io:8082
@"
server = "http://repo.alliage.io:8082"
[host."http://repo.alliage.io:8082"]
  capabilities = ["pull", "resolve"]
"@ | docker exec -i okdp-sandbox-control-plane tee /etc/containerd/certs.d/repo.alliage.io:8082/hosts.toml
```

</details>

The console shows pod CPU and memory through metrics-server:

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
       {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/timeoutSeconds", "value": 3},
       {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/timeoutSeconds", "value": 3}]'
```

> The default probe timeout of 1s is too tight for a single-node kind cluster: under
> load the probes fail and the pod is restarted with a new IP.

### 3. Put the repositories in the cluster

Forgejo holds the deployments repositories, the compiled tree among them, and the
service catalogs: the engine reads them, the console writes to them. It is the platform
component [`20-forgejo`](gitops/platform/components/20-forgejo); install it once with
the same release name and values (the platform values, then the component's, as its
compile layers them), the engine takes it over afterwards. Its admin account comes from
a Secret you create first, with a random password:

```sh
kubectl create namespace forgejo
head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' | kubectl -n forgejo create secret generic \
  okdp-forgejo-admin --from-literal=username=okdp-admin --from-file=password=/dev/stdin
helm upgrade --install forgejo-forgejo oci://code.forgejo.org/forgejo-helm/forgejo --version 17.1.7 \
  -n forgejo --create-namespace --wait \
  -f gitops/platform/platform-values.yaml -f gitops/platform/components/20-forgejo/values.yaml
```

Choose the GitOps engine, the object store and the topology of the repositories before
pushing (Argo CD, RustFS and `mono` as committed); the script only edits the layout,
run it without arguments to be asked:

```sh
scripts/configure.sh --engine flux --storage seaweedfs --topology io   # or: scripts/configure.sh -i
git add -A gitops && git commit -m "chore: configure the sandbox"
```

| Topology | Repositories (organization `okdp`) |
|---|---|
| `mono` | `okdp-deployments`: the sources (`platform/`, `projects/`) and the output (`compiled/`, `flux/`, `argocd/`) |
| `io` | `okdp-input` (`platform/`, `projects/`) and `okdp-output` (`compiled/`, `flux/`, `argocd/`) |
| `split` | `okdp-platform`, one `okdp-project-<p>` per project, and `okdp-output` |

Then compile the committed layout and put it on Forgejo, with the service catalogs
`okdp/platform-charts` and `okdp/sandbox-dependencies` (nothing is pushed when the
layout does not compile; `scripts/compile.sh` shows the problems). The script also
puts the CI in the repositories of the sources (`.forgejo/workflows/okdp-gitops.yaml`)
and registers its runner,
[`30-forgejo-runner`](gitops/platform/components/30-forgejo-runner), in Forgejo: once
the platform is up, every push to the sources is compiled into the output repository.
The console and the CI write to the repositories as `okdp-gitops`, a Forgejo user the
script creates, not an admin, with write access to the repositories of the topology
only; it writes its password, random, to Secret `okdp-gitops-bot` in the namespaces of
the console (`okdp-system`) and of the CI runner (`forgejo`), and the runner's
registration secret to `forgejo/okdp-runner-registration`, nowhere else. For `split`,
it also gives the console a Forgejo token of `okdp-gitops` (Secret
`okdp-system/okdp-forgejo-token`) to create the repositories of new projects. It
reaches Forgejo through a `kubectl port-forward` of the current context, as the admin
of Secret `forgejo/okdp-forgejo-admin`; `--dry-run` shows what it would do:

```sh
scripts/configure.sh --push
```

The Forgejo admin's password, for its web UI:
`kubectl -n forgejo get secret okdp-forgejo-admin -o jsonpath='{.data.password}' | base64 -d`.
A sandbox installed before these Secrets existed (its Forgejo admin password and the
console's credentials were committed): `configure.sh --push` gives the admin a new
password, in `okdp-forgejo-admin`, and the console and the CI their own account; the
engine then removes the old Secrets `okdp-gitops-credentials` and `okdp-forgejo-runner`
from every namespace. Remove the old runner left in Forgejo (Site administration,
Actions, Runners: the offline `okdp-gitops`).

Then choose **one** engine (Flux and Argo CD read the output repository).

### 4a. Install with Flux

```sh
flux install --components=source-controller,kustomize-controller,helm-controller
# The chart version must not carry the OCI digest (see gitops/README.md).
kubectl -n flux-system patch deployment helm-controller --type json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--feature-gates=DisableChartDigestTracking=true"}]'
kubectl apply -f gitops/flux/sync.yaml
```

Follow the platform layers, then the project services:

```sh
flux get kustomizations --watch
flux get helmreleases -n okdp-releases
```

### 4b. Install with Argo CD

The console's engine must be `argocd` first (`scripts/configure.sh --engine argocd`,
which sets `gitops.engine` in
[`30-okdp-control-plane-server/values.yaml`](gitops/platform/components/30-okdp-control-plane-server/values.yaml));
commit and push it to Forgejo as above (`configure.sh --push`). Then:

```sh
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/install.yaml
# Layer ordering of the platform components (the sync waves wait for healthy Applications),
# the sign-in with Keycloak and its roles.
kubectl -n argocd patch configmap argocd-cm --type merge \
  --patch-file gitops/argocd/bootstrap/argocd-cm-patch.yaml
kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
  --patch-file gitops/argocd/bootstrap/argocd-rbac-cm-patch.yaml
# argocd-server reads the OIDC TLS setting at startup only.
kubectl -n argocd rollout restart deployment argocd-server
kubectl apply -n argocd -f gitops/argocd/
```

Follow the Applications (one per component and per service):

```sh
kubectl -n argocd get applications --watch
```

The Argo CD UI is at https://argocd.okdp.sandbox once ingress-nginx and cert-manager are up
([`gitops/argocd/ingress.yaml`](gitops/argocd/ingress.yaml)): **Log in via Keycloak** with a
demo user (`adm` and `alice`, realm role `platform_admin`, are admins; the others read-only),
or user `admin`, password in secret `argocd/argocd-initial-admin-secret`.

Either way, nothing else is applied by hand: the engine deploys the four platform layers
in order, then the demo project (Flux starts the projects once the platform is ready;
Argo CD retries them until it is). Everything is ready after 15 to 30 minutes, depending
on the machine and the network.

Then turn on Forgejo's sign-in with Keycloak, once: restart Forgejo (it reads the sandbox
CA bundle at startup, and the platform creates the bundle after Forgejo's bootstrap), then
create its OAuth source (in Forgejo's database: the chart would recreate it at every start,
which then needs Keycloak up):

```sh
kubectl -n forgejo rollout restart deployment forgejo
kubectl -n forgejo rollout status deployment forgejo
kubectl -n forgejo exec deploy/forgejo -c forgejo -- forgejo admin auth add-oauth \
  --name keycloak --provider openidConnect --key forgejo --secret myForgejoSecret \
  --auto-discover-url https://keycloak.okdp.sandbox/realms/master/.well-known/openid-configuration \
  --group-claim-name groups --admin-group platform_admin
```

### Proxy (optional)

If the cluster reaches the Internet through a proxy, set it on the engine's controllers
(Flux: `kubectl -n flux-system set env deploy -l app.kubernetes.io/part-of=flux HTTPS_PROXY=… NO_PROXY=…`;
Argo CD: the same on `argocd-repo-server`), and for the services in
[`gitops/platform/platform-values.yaml`](gitops/platform/platform-values.yaml)
(`global.okdp.proxy`), committed and pushed.

### Another domain (optional)

The ingress suffix and the OIDC URLs (the five endpoints and the DCR registration URL)
are in [`gitops/platform/platform-values.yaml`](gitops/platform/platform-values.yaml).
Change `okdp.sandbox` there (and in the Forgejo, storage and Keycloak component values that
name hosts, and in `gitops/argocd/ingress.yaml` and `gitops/argocd/bootstrap/argocd-cm-patch.yaml`),
commit and push: every release is re-rendered.

### OAuth clients of the services (optional)

The sandbox registers the services' OAuth clients by dynamic client registration
(`global.okdp.oidc.clientProvisioning: dcr`): each service's oidc-dcr Job registers its
client in Keycloak (anonymous registration, `anonymousDCR` in
[`20-keycloak`](gitops/platform/components/20-keycloak/values.yaml)) and writes it to Secret
`<release>-<namespace>-dcr`. The Job runs `quay.io/adaltas/oidc-dcr-job`.
The console's own client (`okdp-ui`) stays declared in the Keycloak realm. The alternative is
`clientProvisioning: existing` (drop the `dcr` block): the services then use the clients declared in
`20-keycloak` and their Secrets `creds-<release>-oauth2` (`projects/demo/services/secrets`).
Anonymous registration does not check where a registration comes from (`checkSenderHost: false`):
fine on a sandbox, see the keycloak chart before exposing such a Keycloak.

### 5. DNS setup

Enable access to OKDP services through DNS resolution for `okdp.sandbox` (or your domain):

- **Option 1 (recommended)**: local DNS server configuration (automatic for all services)
- **Option 2**: manual `/etc/hosts` configuration

See [dns-configuration.md](docs/dns-configuration.md) for your operating system.

### 6. SSL certificate

The sandbox uses a local certificate authority. Import it into your system or browser
trust store to avoid warnings:

```sh
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > okdp-sandbox-ca.crt
```

See [install-certificate.md](docs/install-certificate.md). Otherwise, open
https://keycloak.okdp.sandbox first and accept its certificate: every OKDP service talks
to Keycloak.

## Using the sandbox

1. **Console**: https://okdp-ui.okdp.sandbox, login `adm` / `adm` (Keycloak).
2. **The demo project** is deployed with the platform: `projects/demo` in Git, namespace
   `demo`. Its services appear in the console like the ones you deploy from it.
3. **Deploy a service** from the console, or commit the same files: see
   [gitops/README.md](gitops/README.md) (`instance.yaml`, `values.yaml`), and push the
   commit to the repository of the sources on Forgejo (`okdp/okdp-deployments` in
   `mono`): the CI compiles it (the **Actions** tab of the repository) and the engine
   deploys the output. From this repository, `scripts/configure.sh --push` puts HEAD
   there, and refuses to overwrite what the console committed since. Everything shows
   up in Forgejo (https://forgejo.okdp.sandbox, **Sign in with keycloak**: `adm` and
   `alice` are site admins): the commits of the sources (the console's, yours), then
   the CI's compile of the output (`okdp: compile`). The
   [okdp CLI](https://github.com/OKDP/okdp-control-plane-cli) does the same from a
   terminal: `okdp login https://okdp-ui.okdp.sandbox` (device flow or browser, the
   console client allows both; add `--insecure-skip-tls-verify` if the sandbox
   certificate is not installed), then `okdp service deploy`.
4. **Examples**: move `gitops/optional/projects/demo/services/okdp-examples` to
   `gitops/projects/demo/services/`, commit and push (`scripts/configure.sh --push`):
   the seed Job loads the NYC-taxi lakehouse. Then follow the
   [okdp-examples guide](https://github.com/OKDP/okdp-examples).

## Optional components

Move a directory of [`gitops/optional/platform/components`](gitops/optional/platform/components)
to `gitops/platform/components/`, commit and push (`scripts/configure.sh --push`).
Remove it the same way (deletion-protected objects, labelled `okdp.io/protected`, must be
unlabelled first).

- **vault**, a secret backend a console `SecretStore` can point at, in dev mode
  (in-memory, sealed on restart).

The object store (`20-storage`) is SeaweedFS or RustFS: `scripts/configure.sh
--storage seaweedfs|rustfs` swaps the component with the one parked in
[`gitops/optional/storage`](gitops/optional/storage) and rewrites the connection files'
`internalUrl`. Choose before the first install: a new store starts empty. It can also be
replaced by any other S3-compatible store:
point `gitops/projects/demo/connections/demo-storage.yaml` at it, provide the credentials
Secrets its `secretRef` and the services' `s3SecretRef` name, and create the buckets.

## Cleanup

```sh
kind delete cluster --name okdp-sandbox
rm /tmp/okdp-sandbox-config.yaml
```

If you trusted the sandbox CA, remove it too: see
[install-certificate.md](docs/install-certificate.md#removing-the-certificate).

## License

This project is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
