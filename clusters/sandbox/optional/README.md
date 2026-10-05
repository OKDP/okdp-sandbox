# Optional components

Nothing in this directory is applied by the sandbox install. Each subdirectory
holds a component the platform can run on but does not need, so applying one is
a deliberate act with consequences worth reading first.

## kubauth

The sandbox authenticates against **Keycloak**. Kubauth is the other identity
provider OKDP supports, and it is the one the Control Plane's user and group
screens talk to: it stores users, groups and OIDC clients as custom resources,
which is what makes them manageable through the API server.

Without it, `/api/v1/identity` answers `501` and the console hides the Identity
area entirely. That is a correct state, not a failure.

Installing it does not switch the platform over. Two things stay on Keycloak
until you change them yourself: the `oidc` block of the platform
Context, which every service reads to find its login endpoints, and the console
sign-in. Running both providers side by side means users exist in two places.

### Install

```sh
kubectl apply -f clusters/sandbox/optional/kubauth/kubauth.yaml
kubectl -n kubocd-system wait --for=jsonpath='{.status.phase}'=READY release/kubauth --timeout=10m
```

Then create the first administrator, since kubauth ships with no bootstrap
account:

```sh
kubectl apply -f clusters/sandbox/optional/kubauth/admin.yaml
```

That gives you `useradmin` / `password`, in the `admins` group. Change the hash
in `admin.yaml` before doing anything you would regret.

### Point the Control Plane at it

Three keys, all of them needed, in the single `platform` Context in
`okdp-system`. Each was checked on the sandbox: with any one missing, the
screens stay empty or unavailable.

**1. Open the routes.** The Identity API answers only when the provider is
kubauth:

```sh
kubectl -n okdp-system patch context platform --type=merge \
  -p '{"spec":{"context":{"identity":{"provider":"kubauth"}}}}'
```

**2. Say where the users live:**

```sh
kubectl -n okdp-system patch context platform --type=merge \
  -p '{"spec":{"context":{"identity":{"kubauth":{"namespace":"kubauth-users"}}}}}'
```

**3. Hand the OIDC clients over to kubauth**, so the console offers to mint a
client rather than asking for the name of an existing Secret:

```sh
kubectl -n okdp-system patch context platform --type=merge \
  -p '{"spec":{"context":{"identity":{"provisioning":{"provider":"kubauth"}}}}}'
```

The server refuses to start when this says kubauth and the kubauth CRDs are
absent, so install the component first.

**4. Tell the packages the same thing.** The three keys above are read by the
server. A package mints its own client from a second pair, under `oidc`, and
without them a Release stays on the Secret it is handed:

```sh
kubectl -n okdp-system patch context platform --type=merge \
  -p '{"spec":{"context":{"oidc":{"clientProvisioning":"kubauth","kubauth":{"namespace":"kubauth-users"}}}}}'
```

Two pairs of keys for one decision is a wart, tracked separately. Set both.

**This third step switches the platform over.** Every package that was handed a
Secret name now generates its own client through kubauth, so the Releases
reconcile against a different provider. Do not run it on a sandbox you need
working in the next few minutes.

Check the whole chain answered:

```sh
kubectl -n okdp-system exec deploy/okdp-control-plane-server-main -- \
  wget -qO- http://localhost:8093/api/capabilities
```

`identity.userManagement` must be `true`. The provider is resolved per request,
so no restart is needed. The console reads the same endpoint at sign-in, so
reload it once for the Identity area to appear.

### Remove

```sh
kubectl delete -f clusters/sandbox/optional/kubauth/admin.yaml
kubectl delete -f clusters/sandbox/optional/kubauth/kubauth.yaml
kubectl -n okdp-system patch context platform --type=merge \
  -p '{"spec":{"context":{"identity":null}}}'
```

## storage

SeaweedFS, the S3 object store of the sandbox, and the producer of the `s3`
Connection the data services consume. Nothing in the platform install depends
on it: only project services (hive-metastore, jupyterhub, polaris,
spark-history-server, and trino through them) require the `storage` role, and
without it their Releases wait in `WAIT_DEPENDENCIES` with an explicit message.

### Install

```sh
kubectl apply -f clusters/sandbox/optional/storage/storage.yaml
kubectl -n kubocd-system wait --for=jsonpath='{.status.phase}'=READY release/storage --timeout=10m
```

`storage.yaml` also lets unauthenticated clients read the cluster OIDC discovery
document and keys (`system:service-account-issuer-discovery`). SeaweedFS needs
them to verify the service account token its provisioning job presents to
assume its role, so the job runs without static keys.

### Bring your own S3 instead

An external S3-compatible store replaces SeaweedFS entirely:

1. Declare the `storage` role as satisfied in the KuboCD Config
   (`clusterRoles: [storage]` in the config content of
   `clusters/sandbox/flux/kubocd.yaml`), so the dependent Releases stop waiting.
2. Declare an `s3` Connection by hand in each project (apiUrl, internalUrl,
   region, pathStyle, secretRef), pointing at the store.
3. Provide the credentials Secret those Connections reference (the sandbox
   uses `creds-seaweedfs-s3`). Buckets and per-service identities are a
   project concern: each project layer creates what its services need.
4. Polaris uses STS: the store must support AssumeRole, or its S3 access needs
   adapting.

### Remove

```sh
kubectl delete release storage -n kubocd-system
```

## vault

The secret backend a Control Plane `SecretStore` can point at, in dev mode
(in-memory, sealed on restart). Nothing depends on it: the platform secrets
come from local-secrets-provider, and the Control Plane's secret-store screens
only need the External Secrets CRDs, which the platform install carries.

### Install

```sh
kubectl apply -f clusters/sandbox/optional/vault/vault.yaml
kubectl -n kubocd-system wait --for=jsonpath='{.status.phase}'=READY release/vault --timeout=10m
```

### Remove

```sh
kubectl delete release vault -n kubocd-system
```
