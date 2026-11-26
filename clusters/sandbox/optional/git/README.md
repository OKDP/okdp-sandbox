# In-cluster Git server

A lightweight Gitea instance inside the cluster used by the walkthrough in [docs/gitops.md](../../../../docs/gitops.md) to run OKDP Sandbox in GitOps mode without an external Git hosting account.

On first start, [git.yaml](git.yaml) provisions one account, one empty private repository (`main` as default branch) on a 1 Gi PersistentVolumeClaim, and an `Ingress` for the browser UI:

| Setting | Value |
|---|---|
| In-cluster Git URL (Flux & Control Plane) | `http://git.git.svc.cluster.local/okdp/okdp-sandbox.git` |
| Browser UI (default `okdp.sandbox` domain) | `https://git.okdp.sandbox` |
| Username / password | `okdp` / `okdp-sandbox` |

> **Local sandbox use only:** do not deploy this server on a shared cluster. Its credentials are fixed in `git.yaml` and its Service is reachable across cluster namespaces.

Follow [docs/gitops.md](../../../../docs/gitops.md) to start it and deploy the sandbox in GitOps mode. To remove it:

```sh
kubectl delete -f clusters/sandbox/optional/git/git.yaml --ignore-not-found
```
