> **Sandbox modes:** [Kubernetes (default)](../README.md#quick-start) | **GitOps mode**

# Running OKDP Sandbox in GitOps Mode

- **Full GitOps in four steps:** Flux reconciles the sandbox prerequisites and the OKDP Control Plane installation from Git, while the Control Plane commits the service catalog and projects under `clusters/sandbox/control-plane/`.
- **Copy-paste ready:** the walkthrough below deploys the optional in-cluster Gitea server so every command works out of the box without an external Git account. To use your own Git server instead, see [Using an external Git server](#using-an-external-git-server).
- **Credentials stay out of Git:** connection and secret-store credentials remain Kubernetes Secrets.

## Contents

- [Overview](#overview)
- [Before you start](#before-you-start)
- [Step 1: Start the in-cluster Git server](#step-1-start-the-in-cluster-git-server)
- [Step 2: Push the sandbox repository](#step-2-push-the-sandbox-repository)
- [Step 3: Connect Flux and deploy](#step-3-connect-flux-and-deploy)
- [Step 4: Verify end-to-end](#step-4-verify-end-to-end)
- [Control Plane-only GitOps](#control-plane-only-gitops)
- [Using an external Git server](#using-an-external-git-server)
- [Switching back to Kubernetes mode](#switching-back-to-kubernetes-mode)
- [Troubleshooting](#troubleshooting)

---

## Overview

<p align="center">
  <img src="assets/gitops-overview.svg" alt="OKDP Control Plane in GitOps mode: end-to-end flow" />
</p>
<p align="center"><em>Control Plane GitOps flow: console changes are committed to Git and reconciled to Kubernetes.</em></p>

---

## Before you start

Complete [1. Clone this repository](../README.md#1-clone-this-repository), [2. Create Kubernetes Kind Cluster](../README.md#2-create-kubernetes-kind-cluster), [Install Flux](../README.md#install-flux-gitops-engine) and [Install metrics-server](../README.md#install-metrics-server) on the main README, stopping before `Install KuboCD`.

*(Want to keep the sandbox prerequisites on `kubectl` and enable GitOps on the Control Plane only? Jump to [Control Plane-only GitOps](#control-plane-only-gitops).)*

## Step 1: Start the in-cluster Git server

[clusters/sandbox/optional/git/git.yaml](../clusters/sandbox/optional/git/git.yaml) starts Gitea inside the cluster with an empty `okdp/okdp-sandbox` repository (`okdp` / `okdp-sandbox`). It is applied with `kubectl` because it hosts the Git repository that Flux and the Control Plane reconcile from, and its `Ingress` exposes **https://git.okdp.sandbox** automatically on the default `okdp.sandbox` domain once `ingress-nginx` and `cert-manager` are Ready *(if using a custom ingress domain with Gitea's browser UI, update `git.okdp.sandbox` in `git.yaml` first)*:

```sh
kubectl apply -f clusters/sandbox/optional/git/git.yaml
kubectl -n git rollout status deploy/git --timeout=5m
```

## Step 2: Push the sandbox repository

*(If you need a custom ingress domain or HTTP proxy, edit `clusters/sandbox/contexts/platform-context.yaml` and commit before pushing.)*

```sh
kubectl -n git port-forward svc/git 3000:80 >/tmp/okdp-git-pf.log 2>&1 &
PF_PID=$!
until curl -fs http://localhost:3000/api/healthz >/dev/null; do kill -0 "$PF_PID" 2>/dev/null || { cat /tmp/okdp-git-pf.log >&2; exit 1; }; sleep 1; done
git remote set-url sandbox-git http://okdp:okdp-sandbox@localhost:3000/okdp/okdp-sandbox.git 2>/dev/null \
  || git remote add sandbox-git http://okdp:okdp-sandbox@localhost:3000/okdp/okdp-sandbox.git
git push -u sandbox-git HEAD:main
kill "$PF_PID" 2>/dev/null || true
```

## Step 3: Connect Flux and deploy

1. Create `okdp-system` and the Git Secrets for Flux (`flux-system`) and for the Control Plane server and its Flux `GitRepository` (`okdp-system`):

   ```sh
   kubectl apply --server-side -f clusters/sandbox/contexts/00-namespace.yaml

   flux create secret git okdp-platform-git --namespace=flux-system \
     --url=http://git.git.svc.cluster.local/okdp/okdp-sandbox.git \
     --username=okdp --password=okdp-sandbox

   flux create secret git okdp-control-plane-git --namespace=okdp-system \
     --url=http://git.git.svc.cluster.local/okdp/okdp-sandbox.git \
     --username=okdp --password=okdp-sandbox
   ```

2. Connect `GitRepository/okdp-platform`, reconcile the foundations, seed the initial catalog `Context` if missing, and deploy the sandbox prerequisites and Control Plane in GitOps mode ([clusters/sandbox/gitops/release-patch.yaml](../clusters/sandbox/gitops/release-patch.yaml) already points at `http://git.git.svc.cluster.local/okdp/okdp-sandbox.git` and `clusters/sandbox/control-plane`):

   ```sh
   flux create source git okdp-platform \
     --namespace=flux-system \
     --url=http://git.git.svc.cluster.local/okdp/okdp-sandbox.git \
     --branch=main \
     --secret-ref=okdp-platform-git \
     --interval=1m \
     --label=okdp.io/flux-sync=sandbox

   kubectl apply -f clusters/sandbox/optional/flux-sync/foundations.yaml
   kubectl -n flux-system wait --for=condition=Ready \
     -f clusters/sandbox/optional/flux-sync/foundations.yaml --timeout=15m

   # Seed the initial service catalog if missing
   kubectl -n okdp-system get context control-plane >/dev/null 2>&1 \
     || kubectl apply --server-side -f clusters/sandbox/contexts/control-plane-context.yaml

   kubectl apply -f clusters/sandbox/optional/flux-sync/releases-gitops.yaml
   ```

3. Wait for all sandbox Releases (prerequisites and Control Plane) and the Control Plane Flux sync to reach `Ready`:

   ```sh
   kubectl -n flux-system wait --for=condition=Ready kustomization/okdp-releases --timeout=5m
   kubectl wait --for=jsonpath='{.status.phase}'=READY release --all -n kubocd-system --timeout=900s
   until kubectl -n okdp-system get kustomization/okdp-control-plane-server-main >/dev/null 2>&1; do sleep 2; done
   kubectl -n okdp-system wait --for=condition=Ready \
     gitrepository/okdp-control-plane-server-main \
     kustomization/okdp-control-plane-server-main --timeout=5m
   ```

## Step 4: Verify end-to-end

Complete [4. DNS Setup](../README.md#4-dns-setup) and [5. SSL Certificate](../README.md#5-ssl-certificate) on the main README, then:

1. Open **https://git.okdp.sandbox** (or `https://git.<CUSTOM_DOMAIN>`, login `okdp` / `okdp-sandbox`) and browse `okdp/okdp-sandbox`: the Control Plane has added two commits initializing `clusters/sandbox/control-plane/contexts/control-plane.yaml`.
2. Open **https://okdp-ui.okdp.sandbox** (or `https://okdp-ui.<CUSTOM_DOMAIN>`, login `adm` / `adm`) and create a project named `analytics` (leaving `demo` free if you plan to deploy [`project-demo`](../clusters/sandbox/project-demo/README.md#running-in-gitops-mode)). Refresh Gitea: `Create project analytics` has committed `clusters/sandbox/control-plane/projects/analytics/namespace.yaml`, and `kubectl get namespace analytics` shows the reconciled namespace.

---

## Control Plane-only GitOps

If you installed the sandbox prerequisites with `kubectl` ([Quick start](../README.md#quick-start) up to [sandbox contexts](../README.md#deployupgrade-the-sandbox-contexts), or an already-running Kubernetes-mode sandbox), enable GitOps on the Control Plane alone *(if using a custom ingress domain with Gitea's browser UI, update `git.okdp.sandbox` in `clusters/sandbox/optional/git/git.yaml` first)*:

```sh
kubectl apply -f clusters/sandbox/optional/git/git.yaml
kubectl -n git rollout status deploy/git --timeout=5m

flux create secret git okdp-control-plane-git --namespace=okdp-system \
  --url=http://git.git.svc.cluster.local/okdp/okdp-sandbox.git \
  --username=okdp --password=okdp-sandbox

kubectl apply -k clusters/sandbox/gitops
kubectl wait --for=jsonpath='{.status.phase}'=READY release --all -n kubocd-system --timeout=900s
until kubectl -n okdp-system get kustomization/okdp-control-plane-server-main >/dev/null 2>&1; do sleep 2; done
kubectl -n okdp-system wait --for=condition=Ready \
  gitrepository/okdp-control-plane-server-main \
  kustomization/okdp-control-plane-server-main --timeout=5m
```

Then verify with [Step 4](#step-4-verify-end-to-end). Projects already created in Kubernetes mode keep running and stay visible in the console, but return `409 Conflict` on edit or delete until their manifests are committed to Git.

---

## Using an external Git server

This section is standalone and replaces Steps 1 to 4 above when using your own Git server (no in-cluster Gitea required). Complete [Before you start](#before-you-start) first (or the [Quick start](../README.md#quick-start) up to [sandbox contexts](../README.md#deployupgrade-the-sandbox-contexts) for Control Plane-only GitOps).

> **Production recommendation: use two separate repositories.**
> - **Platform repository** (sandbox prerequisites and Control Plane install under `clusters/<env>/`, read-only for `flux-system` with `cluster-admin` privileges): protect `main` with mandatory pull requests, and replace the sandbox demo secrets in `clusters/sandbox/releases/` with ExternalSecrets or out-of-band Secrets.
> - **Control Plane repository** (catalog and projects, `gitPath: ""`, read-write for `okdp-control-plane-git`): leave `main` open to direct pushes from the Control Plane's deploy key or token.

1. **Prepare your repositories:** create an empty repository for the Control Plane (for example `okdp-control-plane`), then edit `gitUrl`, `gitBranch` and `gitPath` (`""` for a dedicated repository) in [clusters/sandbox/gitops/release-patch.yaml](../clusters/sandbox/gitops/release-patch.yaml) using full `ssh://git@` or `https://` URLs ending in `.git` (never SCP syntax `git@host:org/repo.git` or embedded credentials).
2. **Create `Secret/okdp-control-plane-git` in `okdp-system` with write access** to your Control Plane repository:

   - **SSH deploy key (recommended by Flux for single-repository access):**

     ```sh
     kubectl apply --server-side -f clusters/sandbox/contexts/00-namespace.yaml
     mkdir -p -m 700 "$HOME/.okdp-gitops"
     ssh-keygen -t ed25519 -N "" -f "$HOME/.okdp-gitops/okdp-control-plane.key" -C "okdp-control-plane"
     flux create secret git okdp-control-plane-git --namespace=okdp-system \
       --url=ssh://git@git.example.com/your-org/okdp-control-plane.git \
       --private-key-file="$HOME/.okdp-gitops/okdp-control-plane.key"
     cat "$HOME/.okdp-gitops/okdp-control-plane.key.pub"
     rm -f "$HOME/.okdp-gitops/okdp-control-plane.key"
     ```

     Verify the SSH host key fingerprint printed by `flux create secret git` against your Git server before trusting it, and register the printed `.pub` key on your Control Plane repository **with write access enabled**. Remove the unencrypted local private key once the Secret is created (as above) or store it in a secret vault.

   - <details>
     <summary><strong>HTTPS token (project access token or repository-scoped token)</strong></summary>

     *(Avoid personal long-lived tokens in production, and read the token interactively so it stays out of shell history. Add `--ca-crt-file=./ca.crt` for an internal CA, or `--bearer-token` when required by your Git server.)*

     ```sh
     kubectl apply --server-side -f clusters/sandbox/contexts/00-namespace.yaml
     read -rs -p "Git token: " CONTROL_PLANE_TOKEN; echo
     flux create secret git okdp-control-plane-git --namespace=okdp-system \
       --url=https://git.example.com/your-org/okdp-control-plane.git \
       --username=git --password="$CONTROL_PLANE_TOKEN"
     unset CONTROL_PLANE_TOKEN
     ```

     </details>

3. **Deploy:**

   - **Control Plane-only GitOps** *(prerequisites installed with `kubectl`)*:

     ```sh
     kubectl apply -k clusters/sandbox/gitops
     kubectl wait --for=jsonpath='{.status.phase}'=READY release --all -n kubocd-system --timeout=900s
     until kubectl -n okdp-system get kustomization/okdp-control-plane-server-main >/dev/null 2>&1; do sleep 2; done
     kubectl -n okdp-system wait --for=condition=Ready \
       gitrepository/okdp-control-plane-server-main \
       kustomization/okdp-control-plane-server-main --timeout=5m
     ```

   - **Full GitOps** *(sandbox prerequisites and Control Plane install reconciled by Flux)*: commit your updated `clusters/sandbox/gitops/release-patch.yaml`, push this repository to `https://git.example.com/your-org/okdp-platform.git` (or `ssh://git@...`), then connect `GitRepository/okdp-platform` *(for private repositories, SSH or custom CAs, pass `--secret-ref`: see Flux [`flux create secret git`](https://fluxcd.io/flux/cmd/flux_create_secret_git/) and [`GitRepository` authentication](https://fluxcd.io/flux/components/source/gitrepositories/#secret-reference))* and apply the Flux manifests:

     ```sh
     flux create source git okdp-platform \
       --namespace=flux-system \
       --url=https://git.example.com/your-org/okdp-platform.git \
       --branch=main \
       --interval=1m \
       --label=okdp.io/flux-sync=sandbox

     kubectl apply -f clusters/sandbox/optional/flux-sync/foundations.yaml
     kubectl -n flux-system wait --for=condition=Ready \
       -f clusters/sandbox/optional/flux-sync/foundations.yaml --timeout=15m

     # Seed the initial service catalog if missing
     kubectl -n okdp-system get context control-plane >/dev/null 2>&1 \
       || kubectl apply --server-side -f clusters/sandbox/contexts/control-plane-context.yaml

     kubectl apply -f clusters/sandbox/optional/flux-sync/releases-gitops.yaml
     kubectl -n flux-system wait --for=condition=Ready kustomization/okdp-releases --timeout=5m
     kubectl wait --for=jsonpath='{.status.phase}'=READY release --all -n kubocd-system --timeout=900s
     until kubectl -n okdp-system get kustomization/okdp-control-plane-server-main >/dev/null 2>&1; do sleep 2; done
     kubectl -n okdp-system wait --for=condition=Ready \
       gitrepository/okdp-control-plane-server-main \
       kustomization/okdp-control-plane-server-main --timeout=5m
     ```

4. **Verify:** complete [4. DNS Setup](../README.md#4-dns-setup) and [5. SSL Certificate](../README.md#5-ssl-certificate) on the main README, verify the two bootstrap commits in your Control Plane repository, then open **https://okdp-ui.okdp.sandbox** (or `https://okdp-ui.<CUSTOM_DOMAIN>`, login `adm` / `adm`) and create a project.

---

## Switching back to Kubernetes mode

Switch the Control Plane back from Git to Kubernetes persistence while keeping all deployed projects, data services and volumes intact (`deletionPolicy: Orphan`):

1. Set `persistenceMode: kubernetes` in [clusters/sandbox/gitops/release-patch.yaml](../clusters/sandbox/gitops/release-patch.yaml) (`gitUrl`, `gitBranch`, `gitPath` and `gitSecretName` are ignored in Kubernetes mode).
2. Apply the change:
   - **Full GitOps:** commit `release-patch.yaml`, run `git pull --rebase` if sharing one repository with the Control Plane, then push (with the in-cluster Gitea server, reopen the `port-forward` from [Step 2](#step-2-push-the-sandbox-repository) or push via `https://git.okdp.sandbox/okdp/okdp-sandbox.git`) and reconcile:

     ```sh
     flux -n flux-system reconcile kustomization okdp-releases --with-source
     ```

   - **Control Plane-only GitOps:**

     ```sh
     kubectl apply -k clusters/sandbox/gitops
     ```

3. Wait for the server to remove its Control Plane Flux sync objects:

   ```sh
   kubectl -n okdp-system wait --for=delete \
     gitrepository/okdp-control-plane-server-main \
     kustomization/okdp-control-plane-server-main --timeout=5m
   ```

*(To switch back to Git later, set `persistenceMode: git` again and re-apply. If you stay permanently in Kubernetes mode, you can also delete the dedicated `<release>-gitops` RBAC objects (`ServiceAccount`, `ClusterRole` and `ClusterRoleBinding`) manually. To deploy the optional demo project in GitOps mode, see [project-demo/README.md](../clusters/sandbox/project-demo/README.md#running-in-gitops-mode).)*

## Troubleshooting

```sh
flux -n flux-system get sources git
flux -n flux-system get kustomizations
flux -n okdp-system get sources git
flux -n okdp-system get kustomizations
```

- **`authentication required` or `authorization failed`:** verify `Secret/okdp-control-plane-git` (`okdp-system`, write access required) and `Secret/okdp-platform-git` (`flux-system`).
- **Push rejected (`protected branch hook declined`):** allow the Control Plane deploy key or token to push directly to `gitBranch`.
- **`knownhosts: key mismatch` or `key is unknown`:** verify the server's SSH host key fingerprint, then re-run `flux create secret git` to refresh `known_hosts`.
- **`x509: certificate signed by unknown authority`:** recreate the Secret with `--ca-crt-file=./ca.crt`.
- **`release <name> may be protected by its package` during project deletion:** KuboCD's deletion webhook refuses to prune a hand-crafted Release whose OCI package has not been fetched yet. Patch `spec.protected: false` on that Release (`kubectl -n <project> patch release <name> --type=merge -p '{"spec":{"protected":false}}'`) and reconcile Flux.
