# Manual installation with Helm

This guide installs the sandbox without a GitOps engine: you compile each instance of
[`gitops/`](../gitops) yourself with [okdp-compiler](https://github.com/OKDP/okdp-compiler)
(`okdp-compile`), then install the platform with `helm upgrade --install`, one release at
a time, in the order Flux and Argo CD follow.

The releases are the ones the GitOps install creates: same names (`<project>-<instance>`),
namespaces and values. The commands below give `okdp-compile` the same inputs
[okdp-gitops](https://github.com/OKDP/okdp-gitops) gives it, and the compiled files are
byte for byte the ones of the `compiled/` tree the engines deploy.

- [What is installed](#what-is-installed)
- [Prerequisites](#prerequisites)
- [Step 1. Clone this repository](#step-1-clone-this-repository)
- [Step 2. Install okdp-compile](#step-2-install-okdp-compile)
- [Step 3. Prepare the working directory](#step-3-prepare-the-working-directory)
- [Step 4. Fetch the service catalogs](#step-4-fetch-the-service-catalogs)
- [Step 5. Define the helpers](#step-5-define-the-helpers)
- [Step 6. Compile every instance](#step-6-compile-every-instance)
- [Step 7. Create the kind cluster](#step-7-create-the-kind-cluster)
- [Step 8. Layer 00: CRDs and operators](#step-8-layer-00-crds-and-operators)
- [Step 9. Layer 10: infrastructure](#step-9-layer-10-infrastructure)
- [Step 10. Layer 20: identity, storage, databases](#step-10-layer-20-identity-storage-databases)
- [Step 11. The demo project](#step-11-the-demo-project)
- [Step 12. DNS and certificate](#step-12-dns-and-certificate)
- [Using the platform](#using-the-platform)
- [Changing an instance](#changing-an-instance)
- [Cleanup](#cleanup)

## What is installed

The platform components of [`gitops/platform/components`](../gitops/platform/components),
layer by layer, then the services of the demo project
[`gitops/projects/demo`](../gitops/projects/demo).

Four components are left out, because they only make sense with a GitOps engine:

| Component | Why it is left out |
|---|---|
| `20-forgejo` | holds the deployments repositories the engines read: nothing reads them here |
| `30-forgejo-runner` | the CI that compiles each push to those repositories |
| `30-okdp-control-plane-server`, `30-okdp-control-plane-ui` | the console commits to the deployments repositories and reads the status of the Flux HelmReleases or Argo CD Applications (`GITOPS_ENGINE` must be `flux` or `argocd`) |

There is no console. Changes are applied to the platform by editing `gitops/`, compiling again and
running Helm again (see [Changing an instance](#changing-an-instance)).

Nothing reconciles the releases either: a failed install is not retried and a manual change
on the cluster is not reverted. Each step waits for its release (`helm --wait`) before the
next one starts.

The [security notice](../README.md#security-notice) of the README applies: the sandbox ships
published demo credentials, and must not be exposed beyond localhost.

## Prerequisites

- 16 GB RAM and 4 CPUs at least for the platform; the whole demo project needs about 32 GB.
- [Docker](https://docs.docker.com/get-docker/) or a compatible container runtime,
  [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation),
  [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/),
  [Helm](https://helm.sh/docs/intro/install/) (tested with Helm 4.3.0), `git`, `curl`, and
  [yq](https://github.com/mikefarah/yq) v4.
- Network access to the chart repositories and image registries of the upstream charts.


**Run every command in one shell**: the steps share variables and functions.

## Step 1. Clone this repository

```sh
git clone https://github.com/OKDP/okdp-sandbox.git
cd okdp-sandbox
```

To use SeaweedFS instead of RustFS as the object store (`20-storage`), switch it now,
before compiling. The script only edits `gitops/`:

```sh
scripts/configure.sh --storage seaweedfs
```

## Step 2. Install okdp-compile

### Install release

Use okdp-compile ≥0.4.0. Download it from the
[releases](https://github.com/OKDP/okdp-compiler/releases) and check it:

```sh
version=0.4.0 os=linux arch=amd64
url=https://github.com/OKDP/okdp-compiler/releases/download/v$version
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
curl -fsSLO "$url/okdp-compile_${version}_${os}_${arch}.tar.gz"
curl -fsSLO "$url/okdp-compile_${version}_checksums.txt"
sha256sum --ignore-missing -c "okdp-compile_${version}_checksums.txt"   # macOS: shasum -a 256
tar -xzf "okdp-compile_${version}_${os}_${arch}.tar.gz" -C ~/.local/bin okdp-compile
cd - >/dev/null
okdp-compile --version    # 0.4.0
```

### Compile sources (alternative)

With Go 1.27 or later, `go install github.com/okdp/okdp-compiler/cmd/okdp-compile@v0.4.0`
works too. Add `~/.local/bin` (or `$(go env GOPATH)/bin`) to your `PATH` if needed.

## Step 3. Prepare the working directory

`OKDP` is the layout, `WORK` holds what the next steps fetch and write: the catalogs, their
contracts, and the compiled instances, one directory per release in
`$WORK/compiled/<namespace>/<release>/`.

```sh
export OKDP="$PWD/gitops" WORK="$HOME/okdp-manual"
mkdir -p "$WORK/catalogs" "$WORK/contracts" "$WORK/compiled"
```

## Step 4. Fetch the service catalogs

An instance names a package, `catalog/<service>/<version>/` of one of the catalogs that
[`platform/catalog.yaml`](../gitops/platform/catalog.yaml) lists, at its `ref`. The
contracts of the connections are the union of the catalogs' `contracts/` directories.

```sh
for name in platform-charts sandbox-dependencies; do
  ref=$(yq -r ".repositories[] | select(.name == \"$name\") | .ref" "$OKDP/platform/catalog.yaml")
  git clone --quiet --depth 1 --branch "$ref" "https://github.com/OKDP/$name.git" "$WORK/catalogs/$name"
  cp "$WORK/catalogs/$name"/contracts/*.schema.json "$WORK/contracts/"
done
ls "$WORK/contracts"
#> database-server.schema.json
#> hive.schema.json
#> iceberg-catalog.schema.json
#> s3.schema.json
#> trino.schema.json
```

If you have checkouts of the catalogs next to this repository, you can export their `ref`
instead of cloning them: replace the `git clone` line with
`mkdir -p "$WORK/catalogs/$name" && git -C "../$name" archive "$ref" | tar -x -C "$WORK/catalogs/$name"`.

## Step 5. Define the helpers

Two shell functions, each taking an instance's directory relative to `gitops/`
(`platform/components/00-cert-manager`, `projects/demo/services/pg`).

`compile` runs `okdp-compile` on a package instance:

| Flag | Value |
|---|---|
| `--package` | `catalog/<service>/<version>/` of the catalog that has it |
| `--contracts` | `$WORK/contracts` |
| `--context` (level 0) | `platform/platform-values.yaml`, then every file of `platform/connections/` |
| `--context 1:` (services only) | the `global` and `connections` keys of `projects/<project>/project.yaml`, when it has any |
| `--context 2:` (services only) | each connection file of `instance.yaml`'s `connections`, from `projects/<project>/connections/` |
| `-f` | the instance's `values.yaml`, then each `upstream.<key>.yaml`, wrapped as `upstream: {<key>: ...}` |
| `--release`, `--namespace` | `<project>-<name>`, and `<project>` (`instance.yaml`) |
| `--published` | `$WORK/compiled/<project>`: what the instances of the namespace compiled so far publish, so a reference can name one of their outputs |
| `-o` | `$WORK/compiled/<project>/<release>`: the output directory |

A plain chart (`chart:` in `instance.yaml`: CloudNativePG, External Secrets) has no package
and is not compiled: `install` gives Helm its values layers directly.

`install` installs or upgrades one release and waits for it:

- a package instance: the compiled umbrella chart, its dependencies built in a copy of the
  directory (`helm dependency build` adds `Chart.lock` and `charts/`, which the next compile
  into the directory would refuse), with `instance.values.yaml` as its only values file;
- a plain chart: the chart and version of `instance.yaml`, with `-f
  platform/platform-values.yaml`, `-f` each of its connection files, then `-f values.yaml`.

```sh
okdp_field() { yq -r ".$2 // \"\"" "$1/instance.yaml"; }

compile() {
  local dir="$OKDP/$1" name project service version chart release pkg c f key
  name=$(okdp_field "$dir" name) project=$(okdp_field "$dir" project)
  service=$(okdp_field "$dir" service) version=$(okdp_field "$dir" version)
  chart=$(okdp_field "$dir" chart) release="$project-$name"
  if [ -n "$chart" ]; then
    echo "$release: plain chart $chart $version, nothing to compile"
    return
  fi
  for c in "$WORK"/catalogs/*; do
    [ -d "$c/catalog/$service/$version" ] && pkg="$c/catalog/$service/$version"
  done
  [ -n "$pkg" ] || { echo "$release: no package $service $version in the catalogs" >&2; return 1; }
  local args=(--package "$pkg" --contracts "$WORK/contracts" --published "$WORK/compiled/$project"
    --release "$release" --namespace "$project" -o "$WORK/compiled/$project/$release"
    --context "$OKDP/platform/platform-values.yaml")
  for f in "$OKDP"/platform/connections/*.yaml; do args+=(--context "$f"); done
  case "$1" in
  projects/*)
    yq '{"global": .global, "connections": .connections} | with_entries(select(.value != null))' \
      "$OKDP/projects/$project/project.yaml" > "$WORK/project-$project.yaml"
    [ "$(yq 'length' "$WORK/project-$project.yaml")" = 0 ] || args+=(--context "1:$WORK/project-$project.yaml")
    for c in $(yq -r '.connections[]' "$dir/instance.yaml"); do
      args+=(--context "2:$OKDP/projects/$project/connections/$c.yaml")
    done ;;
  esac
  args+=(-f "$dir/values.yaml")
  for f in $(find "$dir" -maxdepth 1 -name 'upstream.*.yaml' | sort); do
    key=${f##*/upstream.} key=${key%.yaml}
    yq "{\"upstream\": {\"$key\": .}}" "$f" > "$WORK/upstream-$release-$key.yaml"
    args+=(-f "$WORK/upstream-$release-$key.yaml")
  done
  mkdir -p "$WORK/compiled/$project"
  echo "== $release"
  okdp-compile "${args[@]}"
}

install() {
  local dir="$OKDP/$1" name project chart version release c chartdir rc
  name=$(okdp_field "$dir" name) project=$(okdp_field "$dir" project)
  chart=$(okdp_field "$dir" chart) version=$(okdp_field "$dir" version)
  release="$project-$name"
  echo "== $release"
  if [ -n "$chart" ]; then
    local args=(-f "$OKDP/platform/platform-values.yaml")
    for c in $(yq -r '.connections[]' "$dir/instance.yaml"); do
      case "$1" in
      projects/*) args+=(-f "$OKDP/projects/$project/connections/$c.yaml") ;;
      *) args+=(-f "$OKDP/platform/connections/$c.yaml") ;;
      esac
    done
    helm upgrade --install "$release" "$chart" --version "$version" \
      --namespace "$project" --create-namespace --wait --timeout 15m \
      "${args[@]}" -f "$dir/values.yaml"
  else
    chartdir=$(mktemp -d)
    cp -R "$WORK/compiled/$project/$release/." "$chartdir"
    helm dependency build "$chartdir" &&
      helm upgrade --install "$release" "$chartdir" \
        --namespace "$project" --create-namespace --wait --timeout 15m \
        -f "$WORK/compiled/$project/$release/instance.values.yaml"
    rc=$?
    rm -rf "$chartdir"
    return $rc
  fi
}
```

## Step 6. Compile every instance

Compile the platform components, then the demo services. Within the demo project, an
instance that references an output of another must be compiled after it (`--published`
only knows what is already compiled): `pg` first, which publishes the databases, then
`hive` and `polaris`, which `trino` references, then `trino`, which `superset` references.

```sh
compile platform/components/00-cert-manager
compile platform/components/00-cloudnative-pg
compile platform/components/00-external-secrets
compile platform/components/00-spark-operator
compile platform/components/00-tools
compile platform/components/10-cert-issuers
compile platform/components/10-ingress-nginx
compile platform/components/10-coredns-patch
compile platform/components/10-dns-server
compile platform/components/10-local-secrets-provider
compile platform/components/10-spark-rbac
compile platform/components/20-trust-bundle
compile platform/components/20-cnpg-postgresql
compile platform/components/20-keycloak
compile platform/components/20-storage

compile projects/demo/services/secrets
compile projects/demo/services/pg
compile projects/demo/services/hive
compile projects/demo/services/polaris
compile projects/demo/services/trino
compile projects/demo/services/superset
compile projects/demo/services/airflow
compile projects/demo/services/jupyterhub
compile projects/demo/services/spark-history
```

Each compile prints the release it writes, and the instances it waits for, one line per
parameter that references another instance (`depends on <release> (<contract>, <parameter>)`):
the order of the install steps below follows them.

```text
...
== demo-pg
== demo-hive
depends on demo-pg (database-server demo-pg-hive, db)
== demo-polaris
depends on demo-pg (database-server demo-pg-polaris, db)
== demo-trino
depends on demo-hive (hive, hiveCatalogs[0].metastore)
depends on demo-polaris (iceberg-catalog, icebergCatalogs[0].catalog)
...
== demo-superset
depends on demo-trino (trino, datasources[0].trino)
...
depends on demo-pg (database-server demo-pg-superset, metadataDb)
== demo-airflow
depends on demo-pg (database-server demo-pg-airflow, db)
...
```

A compile that fails prints `error:` and the whole report (a parameter the package refuses, a
missing connection, an output no instance publishes yet) and writes nothing. Fix the
instance, or the order, and run its `compile` again.

The compiled directory of a package instance holds the umbrella chart over the upstream
charts of its service (`Chart.yaml`), its values (`instance.values.yaml`), and, when the
instance has some, OKDP's own objects (`okdp.objects.yaml`, rendered by
`templates/okdp.yaml`) and what it publishes (`okdp.info.yaml`):

```sh
ls "$WORK/compiled/demo/demo-trino"
cat "$WORK/compiled/demo/demo-trino/Chart.yaml"
```

## Step 7. Create the kind cluster

The same cluster as the README's, without the registry settings: only the images of the
control plane and of the CI runner, left out here, come from that registry.

```sh
cat > /tmp/okdp-sandbox-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: okdp-sandbox
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
kubectl cluster-info --context kind-okdp-sandbox
```

The port mappings listen on `127.0.0.1` only: keep it that way. Ports 80 and 443 reach
ingress-nginx (installed in step 9), port 30053 the sandbox DNS server.

## Step 8. Layer 00: CRDs and operators

cert-manager, CloudNativePG, External Secrets, the Spark operator, and the cluster tools
(Reloader, the Secret replicator, and the admission policies that protect objects labelled
`okdp.io/protected` from deletion).

```sh
install platform/components/00-cert-manager
install platform/components/00-cloudnative-pg
install platform/components/00-external-secrets
install platform/components/00-spark-operator
install platform/components/00-tools
```

Each `install` ends with `STATUS: deployed`. Check the layer:

```sh
helm list -A
kubectl get pods -A
```

Every pod is `Running`. If an install fails or times out, read the events of its namespace
(`kubectl get events -n <namespace> --sort-by=.lastTimestamp`), fix the cause and run the
same `install` again: it upgrades the failed release.

## Step 9. Layer 10: infrastructure

The cluster issuers and trust-manager, ingress-nginx, the CoreDNS patch (`*.okdp.sandbox`
resolves to ingress-nginx inside the cluster), the sandbox DNS server, the local secrets
provider (the demo credentials, replicated to every namespace), and the Spark RBAC.

```sh
install platform/components/10-cert-issuers
install platform/components/10-ingress-nginx
install platform/components/10-coredns-patch
install platform/components/10-dns-server
install platform/components/10-local-secrets-provider
install platform/components/10-spark-rbac
```

Check the layer: the CoreDNS patch Job is complete, the CA issuer is ready, and the
credentials are replicated (the replicator copies them within seconds):

```sh
kubectl -n kube-system get jobs
kubectl get clusterissuers
kubectl get secrets -A | grep creds-keycloak-db
```

## Step 10. Layer 20: identity, storage, databases

The CA trust bundle, the platform PostgreSQL, Keycloak and the object store. Keycloak needs
its database, and the object store registers its OAuth client in Keycloak: install them in
this order.

```sh
install platform/components/20-trust-bundle
install platform/components/20-cnpg-postgresql
```

`helm --wait` does not wait for the PostgreSQL cluster itself: wait until it is healthy and
the Keycloak database exists before installing Keycloak.

```sh
kubectl -n cnpg-system wait clusters.postgresql.cnpg.io --all --for=condition=Ready --timeout=10m
kubectl -n cnpg-system wait databases.postgresql.cnpg.io --all --for=jsonpath='{.status.applied}'=true --timeout=5m
```

```sh
install platform/components/20-keycloak
install platform/components/20-storage
```

Keycloak takes a few minutes to start. Check the layer:

```sh
kubectl get bundles
kubectl get pods -A
kubectl get ingress -A
```

The bundle `certs-bundle` is `Synced`, every pod is `Running` or `Completed`, and the
ingresses of Keycloak and of the object store are listed. The platform is up.

## Step 11. The demo project

The services of `projects/demo`, in the order of their dependencies (step 6): the
credentials first, then the PostgreSQL that publishes the databases of the services.

```sh
install projects/demo/services/secrets
install projects/demo/services/pg
kubectl -n demo wait clusters.postgresql.cnpg.io --all --for=condition=Ready --timeout=10m
kubectl -n demo wait databases.postgresql.cnpg.io --all --for=jsonpath='{.status.applied}'=true --timeout=5m
```

Then the services. Those with a sign-in register their OAuth client in Keycloak before
they start (the oidc-dcr Job, a Helm pre-install hook).

```sh
install projects/demo/services/hive
install projects/demo/services/polaris
install projects/demo/services/trino
install projects/demo/services/superset
install projects/demo/services/airflow
install projects/demo/services/jupyterhub
install projects/demo/services/spark-history
```

Check the project:

```sh
helm list -n demo
kubectl get pods -n demo
```

Every release is `deployed`, every pod `Running` or `Completed`.

## Step 12. DNS and certificate

To open the services from your machine, resolve `okdp.sandbox` with the sandbox DNS server
or `/etc/hosts`: see [dns-configuration.md](dns-configuration.md).

The sandbox uses its own certificate authority. Import it into your system or browser trust
store to avoid warnings, and remove it after use:

```sh
kubectl get secret default-issuer -n cert-manager -o jsonpath='{.data.ca\.crt}' | base64 -d > okdp-sandbox-ca.crt
```

See [install-certificate.md](install-certificate.md). Otherwise, open
https://keycloak.okdp.sandbox first and accept its certificate: every service talks to
Keycloak.

## Using the platform

Sign in with Keycloak, as `adm` / `adm` (realm role `platform_admin`), or another demo user
of [`20-keycloak`](../gitops/platform/components/20-keycloak/values.yaml).

| Service | URL |
|---|---|
| Keycloak | https://keycloak.okdp.sandbox |
| Object store console | https://storage-default.okdp.sandbox |
| Trino | https://trino-demo.okdp.sandbox |
| Superset | https://superset-demo.okdp.sandbox |
| Airflow | https://airflow-demo.okdp.sandbox |
| JupyterHub | https://jupyterhub-demo.okdp.sandbox |
| Polaris console | https://polaris-console-demo.okdp.sandbox |
| Spark History Server | https://spark-web-proxy-demo.okdp.sandbox |

Each compiled instance that publishes something lists its URL and usage in its
`okdp.info.yaml`:

```sh
yq '.url, .usage' "$WORK/compiled/demo/demo-superset/okdp.info.yaml"
```

The examples of [okdp-examples](https://github.com/OKDP/okdp-examples) are a service of the
demo project too: move `gitops/optional/projects/demo/services/okdp-examples` to
`gitops/projects/demo/services/`, then `compile projects/demo/services/okdp-examples` and
`install projects/demo/services/okdp-examples`.

## Changing an instance

`gitops/` stays the source: edit the instance's `values.yaml` (or `instance.yaml`, to
change its version or connections), compile it again, and install it again, which upgrades
the release:

```sh
compile projects/demo/services/trino
install projects/demo/services/trino
```

When the change alters what the instance publishes (its outputs), compile and install the
instances that reference it again too (step 6 lists them).

To add a service, write its directory under `gitops/projects/demo/services/`
([gitops/README.md](../gitops/README.md#files-written-by-people-and-by-the-console)), then
`compile` and `install` it after the instances it references.

To remove a release: `helm uninstall <release> --namespace <namespace>`. The objects
labelled `okdp.io/protected` (CRDs, operators) are refused deletion by the policies of
`00-tools`: remove the label first.

## Cleanup

```sh
kind delete cluster --name okdp-sandbox
rm -rf "$WORK" /tmp/okdp-sandbox-config.yaml
```

If you trusted the sandbox CA, remove it too: see
[install-certificate.md](install-certificate.md#removing-the-certificate).
