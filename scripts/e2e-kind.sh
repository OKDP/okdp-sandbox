#!/usr/bin/env bash
#
# Copyright 2026 The OKDP Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# End-to-end test of one GitOps engine on a throwaway kind cluster, the way the
# README installs the sandbox: kind cluster argocd or fluxcd (own kubeconfig, the
# current context is never used), Forgejo bootstrapped with helm from the 20-forgejo
# component (then adopted by the engine), the repositories of the topology and the
# service catalogs put on it by scripts/configure.sh --push (organization okdp,
# http://forgejo-http.forgejo.svc.cluster.local:3000/okdp/<repository>.git, branch
# main), the engine, its entry point (the output repository), then a wait until every
# release is ready. Then the CI of the sources: a plain commit pushed to the repository
# of the platform's sources (a Secret added to 10-local-secrets-provider) must be
# compiled by the CI runner (30-forgejo-runner) into the output and deployed.
#
# What is pushed is a copy of the layout at E2E_REF, adapted for the test:
#   - scripts/configure.sh sets the control plane server's gitops.engine to the engine
#     under test and the topology to E2E_TOPOLOGY;
#   - E2E_SERVER_IMAGE and E2E_UI_IMAGE (repository:tag) replace the images of the
#     control plane, E2E_GITOPS_IMAGE the okdp-gitops image of the CI runner
#     (30-forgejo-runner) (load them with E2E_LOAD_IMAGES);
#   - E2E_SKIP_PROJECTS=1 drops projects/ (platform only);
#   - then the copy is committed; scripts/configure.sh --push compiles it.
# The service packages are read from the catalogs of platform/catalog.yaml (Git, at
# their ref): OKDP_CATALOGS, else the checkouts next to this repository, else GitHub
# (scripts/compile.sh); scripts/configure.sh --push copies them to the cluster's
# Forgejo, where the control plane server reads them. The upstream charts come from
# their public repositories.
#
# Usage:
#   e2e-kind.sh up   <flux|argocd>   create, deploy and wait
#   e2e-kind.sh push <flux|argocd>   push E2E_REF again (adapted) to the cluster's Forgejo
#   e2e-kind.sh down <flux|argocd>   delete the cluster
# Environment:
#   E2E_DIR       work directory (kubeconfigs, pushed copy), default ./.e2e
#   E2E_REF       Git ref of this repository to deploy, default HEAD (commit first)
#   E2E_TOPOLOGY  mono (default), io or split (scripts/configure.sh --topology)
#   OKDP_CATALOGS "NAME=DIR|URL ..." where the catalogs are read from
#   E2E_SERVER_IMAGE, E2E_UI_IMAGE   images of the control plane (repository:tag)
#   E2E_GITOPS_IMAGE         the okdp-gitops image of the CI runner (repository:tag)
#   OKDP_GITOPS   the okdp-gitops binary (default: okdp-gitops in PATH)
#   E2E_LOAD_IMAGES          images loaded into the kind node (space separated)
#   E2E_SKIP_PROJECTS        1: platform components only
#   FLUX_VERSION  default v2.9.5          ARGOCD_VERSION  default v3.4.2
#   E2E_TIMEOUT   seconds, default 2400
# Afterwards: KUBECONFIG=$E2E_DIR/<engine>.kubeconfig kubectl ...

set -euo pipefail

ACTION="${1:-}"; ENGINE="${2:-}"
[[ "$ACTION" =~ ^(up|push|down)$ && "$ENGINE" =~ ^(flux|argocd)$ ]] || { sed -n '18,59p' "$0"; exit 2; }

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS/../gitops" && pwd)"
PREFIX="$(git -C "$ROOT" rev-parse --show-prefix)"; PREFIX="${PREFIX%/}"
E2E_DIR="$(mkdir -p "${E2E_DIR:-./.e2e}" && cd "${E2E_DIR:-./.e2e}" && pwd)"
E2E_REF="${E2E_REF:-HEAD}"
E2E_TOPOLOGY="${E2E_TOPOLOGY:-mono}"
E2E_LOAD_IMAGES="${E2E_LOAD_IMAGES:-}"
E2E_SKIP_PROJECTS="${E2E_SKIP_PROJECTS:-}"
E2E_SERVER_IMAGE="${E2E_SERVER_IMAGE:-}"
E2E_UI_IMAGE="${E2E_UI_IMAGE:-}"
E2E_GITOPS_IMAGE="${E2E_GITOPS_IMAGE:-}"
FLUX_VERSION="${FLUX_VERSION:-v2.9.5}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.2}"
E2E_TIMEOUT="${E2E_TIMEOUT:-2400}"
CLUSTER="${ENGINE/#flux/fluxcd}"   # argocd, fluxcd
export KUBECONFIG="$E2E_DIR/$ENGINE.kubeconfig"
COPY="$E2E_DIR/$ENGINE-repo"
G="$COPY/$PREFIX"

log() { echo "[$CLUSTER] $*"; }

if [[ "$ACTION" == down ]]; then
  kind delete cluster --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
  rm -rf "$KUBECONFIG" "$COPY"
  exit 0
fi

# ---------------------------------------------------------- adapted copy
# prepare_copy: $COPY = the repository at E2E_REF with the test adaptations,
# committed on top of E2E_REF (a fresh history each time: the push is forced).
prepare_copy() {
  rm -rf "$COPY"; mkdir -p "$COPY"
  git -C "$(git -C "$ROOT" rev-parse --show-toplevel)" archive "$E2E_REF" | tar -x -C "$COPY"
  [[ -z "$E2E_SKIP_PROJECTS" ]] || rm -rf "$G/projects"/*
  local c image
  for c in server ui; do
    image="E2E_${c^^}_IMAGE"; image="${!image}"
    [[ -n "$image" ]] || continue
    REPO="${image%:*}" TAG="${image##*:}" yq -i '.imageRepository = strenv(REPO) | .imageTag = strenv(TAG)' \
      "$G/platform/components/30-okdp-control-plane-$c/values.yaml"
  done
  if [[ -n "$E2E_GITOPS_IMAGE" ]]; then
    REPO="${E2E_GITOPS_IMAGE%:*}" TAG="${E2E_GITOPS_IMAGE##*:}" \
      yq -i '.okdpGitopsImage.repository = strenv(REPO) | .okdpGitopsImage.tag = strenv(TAG)' \
      "$G/platform/components/30-forgejo-runner/values.yaml"
  fi
  "$SCRIPTS/configure.sh" --root "$G" --engine "$ENGINE" --topology "$E2E_TOPOLOGY" </dev/null >/dev/null
  git -C "$COPY" init -q -b main
  git -C "$COPY" add -A
  git -C "$COPY" -c user.name=e2e -c user.email=e2e@okdp.io commit -q -m "e2e: $(git -C "$ROOT" rev-parse --short "$E2E_REF") adapted for $ENGINE, $E2E_TOPOLOGY topology"
}

# push_copy: the repositories of the topology and the catalogs, on the cluster's
# Forgejo (organization, repositories, split: the server's token Secret).
push_copy() {
  log "pushing $E2E_REF (adapted, $E2E_TOPOLOGY topology) and the catalogs to Forgejo"
  "$SCRIPTS/configure.sh" --root "$G" --push --force
}

if [[ "$ACTION" == push ]]; then
  prepare_copy; push_copy; exit 0
fi

# ------------------------------------------------------------------ cluster
if kind get clusters | grep -qx "$CLUSTER"; then
  log "cluster exists"
  kind export kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
else
  # TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
  # (the containerd registry config_path, for the plain HTTP repo.alliage.io:8082 below)
  kind create cluster --name "$CLUSTER" --kubeconfig "$KUBECONFIG" --wait 120s --config - <<'KIND'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
KIND
fi
# TODO(no-kubocd): temporary registry, revert to quay.io/okdp once the OKDP images are published there.
# The control plane images come from repo.alliage.io:8082, over plain HTTP.
docker exec "$CLUSTER-control-plane" mkdir -p /etc/containerd/certs.d/repo.alliage.io:8082
docker exec -i "$CLUSTER-control-plane" tee /etc/containerd/certs.d/repo.alliage.io:8082/hosts.toml >/dev/null <<'HOSTS'
server = "http://repo.alliage.io:8082"
[host."http://repo.alliage.io:8082"]
  capabilities = ["pull", "resolve"]
HOSTS
[[ "$(kubectl config current-context)" == "kind-$CLUSTER" ]] || { log "unexpected context"; exit 1; }
for image in $E2E_LOAD_IMAGES; do
  kind load docker-image "$image" --name "$CLUSTER"
done

prepare_copy

# -------------------------------------------------------------------- forgejo
# Bootstrap: the same release the engine manages afterwards (forgejo-forgejo in forgejo),
# with the values its compile gives (a plain chart without connection files: the
# platform values, then the component's).
c="$G/platform/components/20-forgejo"
ns="$(yq '.project' "$c/instance.yaml")"
admin="$(yq '.gitea.admin.existingSecret' "$c/values.yaml")"
# The admin account, a random password (README, step 3), kept when the cluster is reused.
if ! kubectl -n "$ns" get secret "$admin" >/dev/null 2>&1; then
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' \
    | kubectl -n "$ns" create secret generic "$admin" --from-literal=username=okdp-admin --from-file=password=/dev/stdin
fi
log "installing Forgejo (bootstrap of the 20-forgejo component)"
helm upgrade --install "$(yq '.project + "-" + .name' "$c/instance.yaml")" "$(yq '.chart' "$c/instance.yaml")" \
  --version "$(yq '.version' "$c/instance.yaml")" -n "$ns" --create-namespace \
  -f "$G/platform/platform-values.yaml" -f "$c/values.yaml" --wait --timeout 10m
push_copy

# ------------------------------------------------------------------- engine
wait_for() {  # wait_for DESCRIPTION COMMAND...: retry until COMMAND succeeds
  local what="$1"; shift
  local deadline=$((SECONDS + E2E_TIMEOUT))
  until "$@"; do
    (( SECONDS < deadline )) || { log "timeout waiting for $what"; return 1; }
    sleep 20
  done
  log "$what: ok"
}

expected="$(find "$G/projects" "$G/platform/components" -name instance.yaml | wc -l)"

if [[ "$ENGINE" == flux ]]; then
  log "installing Flux $FLUX_VERSION"
  flux install --version="$FLUX_VERSION" --components=source-controller,kustomize-controller,helm-controller
  # Chart version without the OCI digest (see gitops/README.md, "Install with Flux").
  kubectl -n flux-system patch deployment helm-controller --type json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--feature-gates=DisableChartDigestTracking=true"}]'
  kubectl -n flux-system rollout status deployment helm-controller --timeout=5m
  kubectl apply -f "$G/flux/sync.yaml"
  flux_ready() {
    local n
    n="$(kubectl get helmreleases.helm.toolkit.fluxcd.io -n okdp-releases -o json 2>/dev/null \
      | jq '[.items[] | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))] | length')"
    log "HelmReleases ready: ${n:-0}/$expected"
    [[ "${n:-0}" == "$expected" ]]
  }
  wait_for "HelmReleases ready" flux_ready
  flux get kustomizations
  flux get helmreleases -n okdp-releases
else
  log "installing Argo CD $ARGOCD_VERSION"
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
  # The health of Applications: the sync waves of the apps of apps (layer ordering);
  # the sign-in with Keycloak and its roles.
  kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$G/argocd/bootstrap/argocd-cm-patch.yaml"
  kubectl -n argocd patch configmap argocd-rbac-cm --type merge --patch-file "$G/argocd/bootstrap/argocd-rbac-cm-patch.yaml"
  # argocd-server reads the OIDC TLS setting at startup only.
  kubectl -n argocd rollout restart deployment argocd-server
  kubectl -n argocd rollout status deployment --timeout=10m
  kubectl -n argocd rollout status statefulset --timeout=10m
  kubectl apply -n argocd -f "$G/argocd/"
  argo_ready() {
    local n
    n="$(kubectl get applications.argoproj.io -n argocd -l okdp.io/instance -o json 2>/dev/null \
      | jq '[.items[] | select(.status.sync.status == "Synced" and .status.health.status == "Healthy"
          and .status.operationState.phase == "Succeeded")] | length')"
    # The operation too: an Application stays Synced/Healthy while a failing hook
    # (e.g. a schema Job) keeps its sync operation retrying.
    log "Applications synced and healthy, last sync succeeded: ${n:-0}/$expected"
    [[ "${n:-0}" == "$expected" ]]
  }
  wait_for "Applications synced and healthy" argo_ready
  kubectl get applications.argoproj.io -n argocd
fi
# Forgejo's sign-in with Keycloak (README, after step 4): Forgejo reads the sandbox CA
# bundle at startup, and the bundle did not exist when it was bootstrapped; then its OAuth
# source, added or updated in Forgejo's database (not by the chart, which would need
# Keycloak at every start).
log "restarting Forgejo, then its OAuth source keycloak"
kubectl -n forgejo rollout restart deployment forgejo
kubectl -n forgejo rollout status deployment forgejo --timeout=5m
forgejo_auth() { kubectl -n forgejo exec deploy/forgejo -c forgejo -- forgejo admin auth "$@"; }
oauth=(--name keycloak --provider openidConnect --key forgejo --secret myForgejoSecret
  --auto-discover-url https://keycloak.okdp.sandbox/realms/master/.well-known/openid-configuration
  --group-claim-name groups --admin-group platform_admin)
id="$(forgejo_auth list | awk '$2 == "keycloak" {print $1}')"
if [[ -n "$id" ]]; then
  forgejo_auth update-oauth --id "$id" "${oauth[@]}"
else
  forgejo_auth add-oauth "${oauth[@]}"
fi

# --------------------------------------------------------- a plain commit deploys
# The CI of the sources (30-forgejo-runner runs the workflow scripts/configure.sh
# --push put in the repositories of the sources): a commit of the sources, pushed to
# Forgejo by neither the console nor configure.sh, is compiled into the output
# repository by the CI, then deployed by the engine. The commit adds a Secret to
# 10-local-secrets-provider; the last commit of the output must be the CI's.
ci_check() (
  PROG=e2e
  ROOT="$G"
  # shellcheck source=lib/topology.sh
  source "$SCRIPTS/lib/topology.sh"
  # shellcheck source=lib/forgejo.sh
  source "$SCRIPTS/lib/forgejo.sh"
  local owner repo dir marker
  work_init
  forgejo_init
  forgejo_connect
  owner="$(forgejo_owner)"
  case "$(topology_current)" in
    mono) repo="$(mono_repo)"; dir=platform ;;
    io) repo="$INPUT_REPO"; dir=platform ;;
    split) repo="$PLATFORM_REPO"; dir=. ;;
  esac
  marker="e2e-$(date +%s)"
  forgejo_git clone -q "$(forgejo_repo_url "$owner" "$repo")" "$WORK/sources"
  M="$marker" yq -i '.secrets += [{"name": "okdp-e2e-ci", "data": {"marker": strenv(M)}}]' \
    "$WORK/sources/$dir/components/10-local-secrets-provider/values.yaml"
  forgejo_git -C "$WORK/sources" commit -q -am "e2e: a plain commit of the sources"
  forgejo_git -C "$WORK/sources" push -q origin HEAD:main
  log "pushed a commit of the sources to $owner/$repo: Secret okdp-e2e-ci ($marker)"
  ci_deployed() {
    [[ "$(kubectl -n okdp-system get secret okdp-e2e-ci -o jsonpath='{.data.marker}' 2>/dev/null | base64 -d)" == "$marker" ]]
  }
  wait_for "the commit compiled by the CI and deployed" ci_deployed
  forgejo_api GET "/repos/$owner/$(output_repo "$(topology_current)")/commits?sha=main&limit=1"
  [[ "$(jq -r '.[0].commit.message' "$FORGEJO_BODY")" == "okdp: compile"* ]] \
    || { log "the last commit of the output is not the CI's: $(jq -r '.[0].commit.message' "$FORGEJO_BODY")"; return 1; }
  log "the output was compiled by the CI"
)
ci_check
log "done; KUBECONFIG=$KUBECONFIG"
