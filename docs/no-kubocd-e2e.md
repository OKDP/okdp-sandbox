# No-KuboCD end-to-end verification

Live verification of the sandbox installed from `gitops/` with **Flux** and with **Argo CD**:
convergence of the platform and the demo project, the engine compare, the console
end-to-end through the control plane server REST API, Keycloak user management, the
registration of the services' OAuth clients by DCR (`clientProvisioning: dcr`, the sandbox
default), and the chart behaviours that can only be checked on a cluster.

Two runs, each on two throwaway kind clusters `nokubocd-flux` and `nokubocd-argocd` created by
`scripts/e2e-kind.sh` (both engines at once) and deleted afterwards:

- the **DCR run**, with the layout of this commit: the whole sandbox with
  `clientProvisioning: dcr`, convergence, the engine compare, the client of every service
  registered by DCR, the console's own client;
- the **first run**, with `clientProvisioning: existing` (the services' clients declared in
  Keycloak): every other row of the results table. Its evidence is kept below; the DCR
  changes do not touch those behaviours (the Keycloak realm only gains the anonymous
  registration settings).

A third, Flux-only **failure handling run** checked the fixes of bugs F1 and F2 (found in the
DCR run), each reproduced first with the previous files or chart: see
[Failure handling](#failure-handling-f1-f2).

## Setup

| | |
|---|---|
| Engines | Flux v2.9.5 (source/kustomize-controller v1.9.5, helm-controller v1.6.4 with `DisableChartDigestTracking`), Argo CD v3.4.2 (progressive syncs) |
| Cluster | kind v0.33.0, Kubernetes v1.37.0, one node per engine |
| Machine | 16 cores, 86 GiB RAM: the full stack (platform + demo project) ran on both clusters at the same time |
| Charts | packaged from the `no-kubocd` heads of platform-packages, sandbox-dependencies and community-packages (every chart `instance.yaml` references); pushed to a local `registry:2` (`nokubocd-registry:5000`, plain HTTP) and referenced through `E2E_CHART_MAP`. No scratch patch in the DCR run (the first run carried the keycloak anti-affinity fix of bug K2, now in the chart) |
| Images | `okdp-control-plane-server:0.9.0` built from okdp-control-plane-server `9911578` (`VERSION=0.9.0`, no patch), `okdp-control-plane-ui:0.9.0` from okdp-control-plane-ui `f7db961`; loaded into kind |
| Versions | cert-manager v1.21.2 + trust-manager v0.25.0, CloudNativePG chart 0.29.1 (operator 1.30.1), External Secrets 2.11.0 (`external-secrets.io/v1`, webhooks on), ingress-nginx controller v1.15.1, CoreDNS 1.14.6 (dns-server), Keycloak 26.7.4 (codecentric keycloakx 7.3.2), SeaweedFS 4.47, spark-operator 2.5.2, JupyterHub chart 4.4.2, Superset on Valkey 9.1.2 |
| Time | first run: platform + demo project converged in about 25 minutes on each engine. DCR run: Argo CD 27/27 Applications Synced/Healthy with a succeeded last sync in about 45 minutes, untouched; Flux 27/27 HelmReleases Ready after about 80 minutes, with the manual recovery of bugs F1 and F2 (first installs timed out on the loaded machine; fixed since). Failure handling run (Flux, fixed files): 27/27 in about 33 minutes, including a forced failed first install |

Both engines serve the same repository, pushed to the in-cluster Gitea; the only e2e
adaptations are the chart registry rewrite, the plain-HTTP registry settings and the
server's `gitops.engine` (see `e2e-kind.sh`).

## Results

| Item | Flux | Argo CD | Evidence |
|---|---|---|---|
| Platform (18 components, layers 00/10/20/30) + demo project (9 services) converge | verified | verified | DCR run: 27/27 on each engine, no failing pod; Argo CD with no intervention, Flux after the recovery of bugs F1 (cert-manager, External Secrets) and F2 (Superset). First run: 27/27, with the live workarounds of bugs K2 (both), A1 (Argo) and K3 (both, environment dependent) |
| Engine compare (`compare-engines.sh`) | verified | | DCR run: the 27 releases, 393 objects, **0 difference**, 4 expected (the server's 3 engine objects and the ESO webhook certificate Secret, as in CI). The oidc-dcr objects are hooks (compared by neither list) and the DCR Secrets are written by the Jobs (not release objects). First run: 29 releases, 418 objects, no rendering difference |
| Services' OAuth clients registered by DCR | verified | verified | DCR run, see [Client registration](#client-registration-dcr): 7 clients registered by 7 oidc-dcr Jobs of 6 releases in the one namespace `demo`, each in its Secret, listed by Keycloak, used by its service |
| Console's own client (`okdp-ui`, declared in the realm) | verified | verified | DCR run: the UI's `OIDC_CLIENT_ID` is `okdp-ui`; authorization code + PKCE login of `adm` with `okdp-ui` through the ingress, token with its `groups`; `GET /api/projects` with it: 200 `["demo"]`; `/api/capabilities`: Keycloak user management on |
| Console e2e through the REST API | verified | verified | project, external `s3` connection (existing Secret), deploy `spark-history-server`, merge-patch edit (`cpu: 1`, `roleMapping.view_groups: null` removed; limit 500m → 1 after the engine upgrade), delete, delete project; after each of the 6 steps the Gitea content equals the `render-flux.sh` output; the engine converged. The PATCH answers at once (the Git store deadlock is fixed). The service needs its OAuth client Secret `creds-<release>-oauth2` (`clientProvisioning: existing`), created by the test as an admin would |
| Commit author / committer / trailer | verified | verified | `author=adm adm <adm@okdp.io>`, `committer=OKDP control plane <okdp-control-plane@okdp.io>`, subjects `okdp: create project e2eflux by adm`, `okdp: deploy e2eflux/history by adm`, `okdp: update …`, `okdp: delete …`, trailer `Co-Authored-By: okdp-control-plane-server v0.9.0 <okdp-control-plane@okdp.io>` |
| Git credentials from `okdp-gitops-credentials` | verified | verified | `gitops.credentialsSecret`, mounted 0440 with `fsGroup: 65534`: every console commit was pushed; no credentials in the repository URL |
| Projects written in Git | verified | verified | `GET /api/projects` lists `demo` (hand-written) without any namespace label |
| Keycloak user management (`/api/v1/identity`), **no manual Admin API grant** | verified | verified | `/api/capabilities` → `{"identity":{"provider":"keycloak","userManagement":true}}`; groups listed as `[]`; group create/update/delete; user create (`comment`, `uid: 4242`, password, group), update (`comment`, `uid: 4243`, `disabled: true`, groups removed), delete, then 404. The service account holds `master-realm` `manage-users, query-groups, query-users, view-users` and the user profile declares `comment` and `uid`, both from `20-keycloak/values.yaml`. **After a Keycloak values change** (keycloak-config-cli ran again, release v2/v3) the roles were still there and a user with `comment`/`uid` was created again |
| Keycloak in production mode | verified | verified | official image `quay.io/keycloak/keycloak:26.7.4`, `kc.sh start`, `KC_HOSTNAME=https://keycloak.okdp.sandbox`, log `Profile prod activated`; issuer `https://keycloak.okdp.sandbox/realms/master`; database from the `keycloak-db` connection |
| trino OPA + OPAL (opal-secrets hook) | verified | verified | same `dcr-trino` instance with `enableOPA` and `enableOPAL`: the pre-install hook Job on `registry.k8s.io/kubectl:v1.36.5` completed and created `dcr-trino-opal-{ssh,master-token,client-token}`; the OPAL client connected to the server and loaded the policy bundle of okdp-examples (1 rego file) |
| Superset login page, Celery on Valkey | verified | verified | `https://superset-demo.okdp.sandbox/login/` 200, `/health` OK, `/login/keycloak` redirects to Keycloak with client `superset`; `demo-superset-redis` runs `valkey/valkey:9.1.2-alpine` (`PONG`), `celery inspect ping` from the worker: `1 node online`; Deployments select on `app.kubernetes.io/{name,instance,component}` |
| Data path trino + hive + seaweedfs | verified | verified | `CREATE SCHEMA bronze.e2e_<engine>` (location `s3a://hive/hive-warehouse/…`), `CREATE TABLE … AS SELECT` from tpch (25 rows), read back |
| Data path trino + polaris (Iceberg) + seaweedfs | verified | verified | with okdp-examples moved into `projects/demo` (it creates the Polaris warehouses): `CREATE SCHEMA iceberg.e2e_<engine>`, CTAS 5 rows at `s3://lakehouse/demo/e2e_<engine>/…`, read back. **Only after the live workaround of bug SW1** (Polaris vended credentials need SeaweedFS STS) |
| External Secrets 2.11 on `v1` | verified | verified | CRDs serve `v1` only (`/apis/external-secrets.io/v1beta1` is 404), stored versions `["v1"]`; every ExternalSecret `SecretSynced`; admission webhooks on |
| Database owner Secrets labelled `cnpg.io/reload` | verified | verified | the six `creds-*-db` Secrets carry the label in every namespace (replicas included); CloudNativePG reconciled every managed role (`keycloak`; `hms`, `superset`, `examples`, `polaris`, `airflow`) with no manual action |
| cert-manager three layers | verified | verified | cert-manager v1.21.2 and trust-manager v0.25.0; every Certificate Ready |
| dns-server (CoreDNS) | verified | verified | `coredns/coredns:1.14.6` on node port 30053: `*.okdp.sandbox` → `127.0.0.1`, other names forwarded (8.8.8.8, 8.8.4.4) |
| Protection ValidatingAdmissionPolicies | verified | verified | server dry-run delete of Deployment `cert-manager-cert-manager` refused by `kube-tools-tools-protected` |
| SeaweedFS 4.47 provisioning | verified | verified | `default-storage-provisioning` (weed shell, no MinIO client) Complete; the Hive and Iceberg writes above land in its buckets |
| spark-operator release Secret size | verified | | Flux release Secret of spark-operator 2.5.2: about 735 KB of the 1 MiB limit |

Rows without "DCR run" in their evidence come from the first run.

Not verified: the browser flows (console login in a browser, interactive OIDC logins of
the services); user tokens were obtained with the authorization code flow (+ PKCE for the
public clients) through the ingress, without changing any client. The Gitea
content check covers the files the console writes, not `flux/components.yaml` (admin
file).

## Client registration (DCR)

Platform values `clientProvisioning: dcr`, `dcr.authMethod: anonymous`,
`dcr.registrationUrl: https://keycloak.okdp.sandbox/realms/master/clients-registrations/openid-connect`;
`20-keycloak`: `anonymousDCR.enabled: true`, `allowedScopes: [profile, email, roles, groups,
offline_access]`, the chart defaults `checkSenderHost: false`, `consentRequired: false`,
`fullScopeAllowed: true`.

| Check | Flux | Argo CD | Evidence |
|---|---|---|---|
| Keycloak anonymous policies | verified | verified | the keycloak-config-cli Job's init container removed Consent Required and Full Scope Disabled: left `allowed-client-templates`, `allowed-protocol-mappers`, `max-clients`, `registration-web-origins`, `trusted-hosts` |
| Registration from pods (sender host not checked) | verified | verified | every oidc-dcr Job registered its client through the ingress (`keycloak.okdp.sandbox`), CA from `certs-bundle`; no "Host not trusted" |
| Several DCR clients in one namespace | verified | verified | `demo`: Jobs, ConfigMaps, ServiceAccounts, Roles and RoleBindings `<release>-oidc-dcr` and `demo-polaris-console-oidc-dcr` (28 objects), none named `dcr` |
| trino | verified | verified | Secret `demo-trino-demo-dcr` (`client_id`, `client_secret`); Keycloak lists the client (`demo-trino-demo`, confidential, no consent, full scope); `https://trino-demo.okdp.sandbox/ui/` redirects to Keycloak with that `client_id` |
| airflow | verified | verified | Secret `demo-airflow-demo-dcr`; Keycloak client `demo-airflow-demo`; `/auth/login/oidc` redirects with that `client_id` |
| superset | verified | verified | Secret `demo-superset-demo-dcr` (sign-in and Trino datasources); Keycloak client `demo-superset-demo`; `/login/keycloak` redirects with that `client_id` |
| jupyterhub | verified | verified | Secret `demo-jupyterhub-demo-dcr`; Keycloak client `demo-jupyterhub-demo`; `/hub/oauth_login` redirects with that `client_id` |
| spark-history-server (spark-web-proxy) | verified | verified | Secret `demo-spark-history-demo-dcr`; Keycloak client `demo-spark-history-demo`; `https://spark-web-proxy-demo.okdp.sandbox/` answers the OIDC filter's redirect page to Keycloak with that `client_id` and `redirect_uri=…/home` |
| polaris (server) | verified | verified | Secret `demo-polaris-demo-dcr`; Keycloak client `demo-polaris-demo` (confidential, `client_credentials`); `QUARKUS_OIDC_CLIENT_ID` and the OIDC client secret read from it |
| polaris console | verified | verified | Secret `demo-polaris-demo-console-dcr` (`client_id`); Keycloak client `demo-polaris-demo-console` (public); the console Deployment's `VITE_OIDC_CLIENT_ID` reads it; PKCE login of `adm` with it: token with the realm roles, CORS allowed for the console origin, `GET /api/management/v1/catalogs` on Polaris with that token: 200 |
| Logins with the registered clients | verified | verified | authorization code flow of `bob` with the trino, airflow, superset, jupyterhub and spark-history-server clients (their redirect URIs and scopes): no consent screen, a refresh token, `groups` `[default-roles-master, offline_access, uma_authorization, data_engineer]` |

## Bugs found

Each item: file, cause, proposed fix. Nothing was changed in other repositories.

### K2. Keycloak: the keycloak-config-cli Job never schedules on a single node (sandbox-dependencies)

- File: `packages/system/keycloak/templates/_values.tpl` (the vendored keycloakx `affinity`
  default).
- Cause: keycloakx gives the StatefulSet a required pod anti-affinity on
  `app.kubernetes.io/{name,instance}` excluding only `component: test`. The
  keycloak-config-cli Job pod carries the same name and instance labels (component
  `keycloak-config-cli`), so on a one-node cluster it stays Pending ("didn't satisfy existing
  pods anti-affinity rules"): the realm is never imported, the Flux install times out and is
  remediated, the Argo sync waits for the PostSync hook forever.
- Proposed fix: set `affinity` in the computed values with
  `NotIn [test, keycloak-config-cli]` (what the e2e chart carries), or drop the required
  anti-affinity (one replica). The e2e pushed that patched chart under the same version.

### D2. Keycloak: anonymous DCR from a pod is refused ("Host not trusted") (sandbox-dependencies)

- File: `packages/system/keycloak/templates/_realm.tpl` (Trusted Hosts policy,
  `host-sending-registration-request-must-match: true`).
- Cause: Keycloak now runs behind the ingress with `proxy.mode: xforwarded`, so the sender of
  a registration is the client address from `X-Forwarded-For`: the oidc-dcr Job pod, whose IP
  has no PTR record, never matches `*.svc.cluster.local` (only Service endpoints such as the
  ingress controller resolve to `….svc.cluster.local`). Every oidc-dcr Job fails with
  `insufficient_scope` (`Policy 'Trusted Hosts' rejected request … Host not trusted`).
- Proposed fix: a parameter (e.g. `anonymousDCR.checkSenderHost`, default `false`) for
  `host-sending-registration-request-must-match`, keeping `client-uris-must-match` on the
  trusted hosts; or DCR with an initial access token. The e2e set the flag to `false` through
  the Admin API after Keycloak was configured (it is not a grant; keycloak-config-cli restores
  it on the next change).

### SW1. SeaweedFS 4.47: STS is off with an empty signing key, Iceberg writes fail (sandbox-dependencies)

- File: `packages/services/seaweedfs/templates/auth.yaml` (`iam.json`, `sts.signingKey: ""`).
- Cause: SeaweedFS 4.47 does not serve STS without a signing key (4.17 did): Polaris cannot
  get subscoped credentials (`Failed to get subscoped credentials: (Service: Sts, Status Code:
  503)`), so every Iceberg `CREATE TABLE` fails with `Failed to create transaction`. The Hive
  path is not affected.
- Proposed fix: a signing key generated once (ESO `Password` generator, 32 bytes) and the
  `iam.json` rendered by an ExternalSecret template (or the key passed by environment), plus a
  live Iceberg CTAS in the chart tests. The e2e wrote a random key into
  `default-storage-auth-config` and restarted `default-storage-s3`.

### K3. coredns-patch: AAAA queries for the sandbox suffix leave the cluster (sandbox-dependencies)

- File: `packages/system/coredns-patch` (the Corefile block it adds: `template IN A` only).
- Cause: `A` queries for `*.okdp.sandbox` are answered in the cluster, `AAAA` queries fall
  through to the upstream resolver. When the host resolver cannot answer the sandbox suffix
  (here a split-DNS rule of the machine pointing at a DNS server that no longer runs), each
  `AAAA` lookup times out: the Trino server (Jetty resolver, 5 s timeout) could not read
  the Keycloak JWKS and crash-looped. The previous run presumably did not hit it because that
  DNS server was still running then.
- Proposed fix: also answer `AAAA` in the cluster, e.g. `template IN AAAA okdp.sandbox { match
  …; rcode NOERROR }` (what the sandbox dns-server already does). The e2e added that block to
  the `coredns` ConfigMap of both clusters and restarted CoreDNS.

### A1. Argo CD: airflow waits forever when the ESO webhook is not ready yet (platform-packages, airflow)

- File: `packages/services/airflow` (the migration Job, `argocd.argoproj.io/hook: Sync`, and
  the ExternalSecret `<release>-internal`).
- Cause: under Argo the projects start with the platform. The first sync of `demo-airflow`
  ran while the ESO admission webhook was not serving yet: the ExternalSecret apply failed
  (`failed calling webhook "validate.externalsecret.external-secrets.io"`), but the operation
  kept waiting for the migration Sync hook, whose pod waits for the Secret that ExternalSecret
  creates. No retry ever came (the previous run had no ESO webhook). Flux is not affected (the
  projects wait for the platform).
- Proposed fix: order the hook after the ExternalSecret (`argocd.argoproj.io/sync-wave: "1"`
  on the migration Job, a documented Argo compensation) and give the Job an
  `activeDeadlineSeconds`, so a failed apply fails the operation and Argo retries. The e2e
  terminated the operation and started a new sync, which succeeded.

### S4. Control plane server: secret stores and external secrets on `v1beta1` (okdp-control-plane-server)

- Files: `internal/repository/crd/secret_store_types.go`,
  `internal/repository/crd/external_secret_types.go` (`Version: "v1beta1"`,
  `external-secrets.io/v1beta1`).
- Cause: ESO 2.11 serves `external-secrets.io/v1` only: `GET
  /api/projects/<p>/secret-stores` and `/external-secrets` answer 501 `the external-secrets CRDs
  are not installed`, so the console's Secrets pages are off.
- Proposed fix: move both types to `v1` (same fields for the Vault provider and the
  ExternalSecret spec the server writes) and probe `v1`.

### Other observations

- Flux: the first keycloak install failed with `failed early due to stalled resources`
  (bug K2 blocked the hook) and was remediated; with the fixed chart the next attempt succeeded.
- Argo CD ApplicationSets have no Gitea webhook in the sandbox: new services appear at the
  generator's polling interval (a few minutes).
- spark-operator release Secret: about 735 KB of 1 MiB (was 731 KB); one more CRD version could
  break Flux installs (Argo does not store releases).

## Failure handling (F1, F2)

Flux-only run on `nokubocd-flux` (the only cluster), same machine, engine and chart registry
as the DCR run; each bug is reproduced first, then the fix is shown on a fresh install. Pod
creation in `external-secrets` was blocked by a `ResourceQuota` (`pods: 0`) created before
Flux started, then removed once the first install had failed: a first install of a protected
release that cannot complete, as on the loaded machine of the DCR run.

| Check | Evidence |
|---|---|
| F1 reproduced (previous HelmReleases: `install.remediation.retries: 3`, platform only) | the External Secrets install timed out after 5 minutes; the uninstall remediation deleted the ServiceAccounts, then stopped on `Deployment external-secrets-external-secrets-cert-controller is protected by OKDP` (`kube-tools-tools-protected`): release `uninstalling`, HelmRelease `Could not determine release state: unable to determine state for release with status 'uninstalling'`. Quota removed: the three ReplicaSets fail with `serviceaccount "external-secrets-…" not found`, no retry possible |
| F1 fixed (these HelmReleases: `install.strategy: RetryOnFailure`, `retryInterval: 2m`, `timeout: 15m`, upgrade remediation `rollback`; platform and demo project) | the External Secrets install failed (`failed early due to stalled resources`), the release stayed `failed` with its ServiceAccounts and Deployments (`installFailures: 1`, `ProgressingWithRetry: retrying after 2m0s`, no uninstall). Quota removed: the retry (Helm upgrade, revision 2) succeeded 2 minutes later, pods running. The platform and the demo project then converged, 27/27 HelmReleases Ready about 33 minutes after the start; no other release failed |
| F2 reproduced (previous superset chart, no keep policy) | database `superset` holding the encrypted password of the `examples` database (decrypted by the app); HelmRelease deleted (the uninstall a remediation does), then re-created: `demo-superset-internal` (ExternalSecret, two Password generators, Secret) deleted by the uninstall, a new `superset_secret_key` generated (SHA-256 `fa303102…` then `51b2d3d0…`), `init-db` failing with `ValueError: Invalid decryption key` at every attempt |
| F2 fixed (this superset chart) | after the reproduction, schema `public` of `superset` dropped and the release reinstalled with this chart. The ExternalSecret and its generators carry `helm.sh/resource-policy: keep` and `argocd.argoproj.io/sync-options: Delete=false`. HelmRelease deleted: no release and no Deployment left, the ExternalSecret, both Password generators and the Secret kept (key SHA-256 `1d89864c…` unchanged). HelmRelease re-created: install succeeded at once (`installFailures` none, `init-db` succeeded), the kept objects adopted by the new release (same creation time), the same key, the `examples` password decrypted |

airflow (`<release>-internal`, `fernet-key`) and jupyterhub (`<release>-hub-generated`,
`hub.config.CryptKeeper.keys`) carry the same keep policy (rendered by the chart tests, not
exercised live). Not changed: trino's `shared-secret` (internal communication only) and the
OPAL secrets (hook-created, not release objects), seaweedfs' STS signing key (sessions
only), polaris' root credentials (already kept).

## Resolved since the first run

- F1, a failed first install of a protected release could not be remediated (Flux): the
  generated HelmReleases no longer uninstall on a failed install (`install.strategy.name:
  RetryOnFailure`, retried in place every 2 minutes), roll back a failed upgrade (3 times),
  and give each Helm action 15 minutes. See [Failure handling](#failure-handling-f1-f2).
- F2, a failed first install left the Superset database encrypted with a lost key: the
  generated secrets whose loss breaks persisted data (superset, airflow, jupyterhub) are kept
  on uninstall and adopted by the next install. See
  [Failure handling](#failure-handling-f1-f2).

- oidc-dcr's Job, ConfigMap and RoleBinding named `dcr` (one DCR client per namespace at a
  time): every chart renders it with `okdp.vendor.oidcDcr`, objects `<release>-oidc-dcr`.
- D2, anonymous DCR from a pod refused ("Host not trusted"): the keycloak chart's
  `anonymousDCR.checkSenderHost` defaults to `false`; no Admin API change in the DCR run.
- K2, keycloak-config-cli Job never scheduled: the chart's anti-affinity leaves the Job pod
  out; no scratch chart in the DCR run.
- Registered clients with a consent screen and no realm role in their tokens (Keycloak's own
  Consent Required and Full Scope Disabled policies) and no refresh token (no `refresh_token`
  grant): the keycloak chart removes both policies, the charts register `refresh_token`.

- Git store deadlock on a parameters PATCH (okdp-control-plane-server): the PATCH answered 200
  at once on both engines, with the unpatched server image.
- Projects written in Git invisible to the console: `demo` is listed.
- Empty group list: `[]` instead of `null`.
- Server chart credentials Secret unreadable: mounted 0440 with `fsGroup: 65534`; the sandbox
  uses `gitops.credentialsSecret: okdp-gitops-credentials` again.
- Keycloak client roles, user profile and upgrades: declared in `20-keycloak/values.yaml`,
  kept across keycloak-config-cli runs; no Admin API grant.
- CloudNativePG role without password when the owner Secret arrives late: the owner Secrets are
  labelled `cnpg.io/reload`; every role reconciled on both engines.
- dns-server Helm 3 / Helm 4 difference: dns-server is now the CoreDNS chart, identical under
  both engines; CI no longer lists it.
- External Secrets OCI chart inconsistent with its binary: ESO 2.11.0 runs with its admission
  webhooks and `v1` only.

## Compare script

`compare-engines.sh` ignores Helm SDK and cluster-bound metadata (the `managed-by` label the
Helm SDK of Flux sets on every object, Job `controller-uid` labels, PVC bindings, injected
`caBundle`s), leaves hooks out of both lists, and reports the objects named in
`COMPARE_EXPECTED` without counting them: CI lists the control plane server's engine objects
(`gitops.engine`) and the External Secrets webhook certificate Secret.

## Workarounds used by the e2e (not in `gitops/`)

Failure handling run: the `external-secrets` ResourceQuota (`pods: 0`, removed after the
first failed install), the superset HelmRelease deleted with `okdp-projects` suspended (the
uninstall under test), the superset schema reset after the F2 reproduction, the fixed
superset, airflow and jupyterhub charts pushed under the same versions. DCR run: the
recovery of bugs F1 and F2 (Flux only). First run:

- Keycloak chart with the K2 anti-affinity patch in the local registry (same version).
- CoreDNS `AAAA` template for the sandbox suffix on both clusters (K3).
- Argo CD: `demo-airflow` operation terminated and a new sync started (A1); after the K2
  chart replaced the pending hook, the `keycloak-keycloak` operation was terminated too.
- Keycloak Admin API: Trusted Hosts policy `host-sending-registration-request-must-match:
  false` (D2). No identity role or user profile change.
- SeaweedFS: STS signing key written into `default-storage-auth-config`, S3 gateway restarted
  (SW1).
- Secret `creds-<project>-history-oauth2` created for the console's spark-history-server
  (`clientProvisioning: existing` prerequisite, a copy of the demo client).
- DCR, OPAL and okdp-examples: commits pushed to the cluster's Gitea as a GitOps user (project
  `dcr` with the instance-level `global` override, `anonymousDCR.enabled` and an
  `allowedScopes` list, okdp-examples moved into `projects/demo`).
