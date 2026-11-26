# Flux sync for sandbox prerequisites and Control Plane install

Flux manifests used by [docs/gitops.md](../../../../docs/gitops.md) to reconcile the sandbox prerequisites and the OKDP Control Plane installation from Git (all Kustomizations carry `okdp.io/flux-sync: sandbox` and `deletionPolicy: Orphan`):

- [foundations.yaml](foundations.yaml): ordered Kustomizations for KuboCD (`flux/`), `contracts/` and platform `contexts/`.
- [releases-gitops.yaml](releases-gitops.yaml): `okdp-releases` pointing at `./clusters/sandbox/gitops`.
