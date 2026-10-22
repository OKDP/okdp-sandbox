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

# Compares the live objects of OKDP releases deployed by Flux on one cluster and by
# Argo CD on another, from the same deployments repository.
#
# For each release <r> (namespace <p>):
#   1. the object list: Flux = the Helm release manifest (helm get manifest), Argo =
#      the Application's status.resources; both lists must be equal;
#   2. every object, fetched from both clusters and normalised: server-populated
#      fields (uid, resourceVersion, generation, creationTimestamp, managedFields,
#      status, Service clusterIP(s)) and engine-specific metadata (labels and
#      annotations under helm.toolkit.fluxcd.io/, kustomize.toolkit.fluxcd.io/,
#      argocd.argoproj.io/, meta.helm.sh/, plus kubectl last-applied-configuration,
#      deployment revision and kustomize config.kubernetes.io/origin) and the
#      caBundle injected into webhook configurations and CRD conversion webhooks
#      (the CAs differ per cluster) are removed; so are the label
#      app.kubernetes.io/managed-by: Helm (the Helm SDK of Flux adds it to every
#      object, Argo only has it where the chart renders it), the Job controller-uid
#      labels and selector, and the PersistentVolumeClaim binding (volumeName,
#      selected node, provisioner annotations); the rest must be identical.
# Hooks are not compared (ephemeral, deleted by their delete policy or TTL): Helm
# hooks are absent from the Helm manifest, Argo hooks (status.resources[].hook) and
# objects annotated argocd.argoproj.io/hook are left out of both lists.
# COMPARE_EXPECTED: space separated <namespace>/<kind.group>/<name> whose
# differences are expected (e.g. the control plane server's gitops.engine, set to
# the engine under test): reported as EXPECTED, not counted.
# Also compares ConfigMap okdp-releases/okdp-platform-values and every
# okdp-releases/okdp-platform-conn-* ConfigMap.
#
# Usage: compare-engines.sh FLUX_KUBECONFIG ARGO_KUBECONFIG [<project>/<release> ...]
#   default: every instance.yaml of this layout.
# Requires kubectl, helm, jq, yq v4. Exit status 1 when anything differs.

set -euo pipefail
export LC_ALL=C

[[ $# -ge 2 ]] || { sed -n '18,47p' "$0"; exit 2; }
FLUX_KC="$1"; ARGO_KC="$2"; shift 2
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gitops" && pwd)"

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  while IFS= read -r f; do
    p="$(yq '.project' "$f")"; i="$(yq '.name' "$f")"
    TARGETS+=("$p/$p-$i")
  done < <(find "$ROOT/projects" "$ROOT/platform/components" -name instance.yaml | sort)
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
differences=0
compared=0
expected=0

NORMALISE='
  def clean($prefixes): with_entries(select(.key as $k | all($prefixes[]; . as $p | $k | startswith($p) | not)));
  del(.metadata.uid, .metadata.resourceVersion, .metadata.generation,
      .metadata.creationTimestamp, .metadata.managedFields, .metadata.selfLink, .status)
  | if .metadata.labels then .metadata.labels |= clean(["helm.toolkit.fluxcd.io/",
      "kustomize.toolkit.fluxcd.io/", "argocd.argoproj.io/"]) else . end
  | if .metadata.labels["app.kubernetes.io/managed-by"] == "Helm"
    then del(.metadata.labels["app.kubernetes.io/managed-by"]) else . end
  | if .kind == "Job" then del(.spec.selector,
      .metadata.labels["batch.kubernetes.io/controller-uid"], .metadata.labels["controller-uid"],
      .spec.template.metadata.labels["batch.kubernetes.io/controller-uid"],
      .spec.template.metadata.labels["controller-uid"]) else . end
  | if .kind == "PersistentVolumeClaim" then del(.spec.volumeName)
      | .metadata.annotations |= (. // {} | clean(["pv.kubernetes.io/", "volume.kubernetes.io/",
          "volume.beta.kubernetes.io/"])) else . end
  | if .metadata.annotations then .metadata.annotations |= clean(["helm.toolkit.fluxcd.io/",
      "kustomize.toolkit.fluxcd.io/", "argocd.argoproj.io/", "meta.helm.sh/",
      "kubectl.kubernetes.io/last-applied-configuration", "deployment.kubernetes.io/revision",
      "config.kubernetes.io/origin"]) else . end
  | if .metadata.labels == {} then del(.metadata.labels) else . end
  | if .metadata.annotations == {} then del(.metadata.annotations) else . end
  | if .kind == "Service" then del(.spec.clusterIP, .spec.clusterIPs) else . end
  | if (.kind == "MutatingWebhookConfiguration" or .kind == "ValidatingWebhookConfiguration")
    then del(.webhooks[]?.clientConfig.caBundle) else . end
  | if .kind == "CustomResourceDefinition" then del(.spec.conversion.webhook.clientConfig.caBundle) else . end
'

# fetch KUBECONFIG KIND.GROUP NAME NAMESPACE OUT
fetch() {
  local kc="$1" res="$2" name="$3" ns="$4" out="$5"
  if kubectl --kubeconfig "$kc" get "$res" "$name" -n "$ns" -o json >"$out.raw" 2>"$out.err"; then
    jq -S "$NORMALISE" "$out.raw" >"$out"
  else
    echo "MISSING: $(cat "$out.err")" >"$out"
  fi
}

compare_object() {  # compare_object KIND.GROUP NAME NAMESPACE
  local res="$1" name="$2" ns="$3" key="${1}_${3}_${2}"
  fetch "$FLUX_KC" "$res" "$name" "$ns" "$TMP/$key.flux"
  fetch "$ARGO_KC" "$res" "$name" "$ns" "$TMP/$key.argo"
  compared=$((compared + 1))
  if diff -u --label "flux $ns/$res/$name" --label "argo $ns/$res/$name" \
       "$TMP/$key.flux" "$TMP/$key.argo" >"$TMP/$key.diff"; then
    echo "   same  $res $ns/$name"
  elif [[ " ${COMPARE_EXPECTED:-} " == *" $ns/$res/$name "* ]]; then
    echo "   EXPECTED  $res $ns/$name"
    sed 's/^/      /' "$TMP/$key.diff"
    expected=$((expected + 1))
  else
    echo "   DIFF  $res $ns/$name"
    sed 's/^/      /' "$TMP/$key.diff"
    differences=$((differences + 1))
  fi
}

echo "== okdp-releases/okdp-platform-values and platform connections"
compare_object configmap okdp-platform-values okdp-releases
for f in "$ROOT"/platform/connections/*.yaml; do
  [[ -f "$f" ]] || continue
  c="${f##*/}"; compare_object configmap "okdp-platform-conn-${c%.yaml}" okdp-releases
done

for t in "${TARGETS[@]}"; do
  ns="${t%%/*}"; r="${t#*/}"
  echo "== release $r (namespace $ns)"
  # kind.group|name, from the Helm manifest (Flux)
  if ! helm --kubeconfig "$FLUX_KC" get manifest "$r" -n "$ns" >"$TMP/$r.manifest" 2>"$TMP/$r.err"; then
    echo "   DIFF  Flux has no Helm release $ns/$r: $(grep -v 'plugins' "$TMP/$r.err")"
    differences=$((differences + 1)); continue
  fi
  yq ea -o=json -I=0 'select(.kind != null and (.metadata.annotations["argocd.argoproj.io/hook"] == null))
      | {"apiVersion": .apiVersion, "kind": .kind, "name": .metadata.name}' \
      "$TMP/$r.manifest" \
    | jq -r '(.kind | ascii_downcase)
        + (if (.apiVersion | contains("/")) then "." + (.apiVersion | split("/")[0]) else "" end)
        + "|" + .name' | sort -u >"$TMP/$r.flux.list"
  # kind.group|name, from the Application status (Argo)
  if ! kubectl --kubeconfig "$ARGO_KC" get applications.argoproj.io "$r" -n argocd -o json >"$TMP/$r.app" 2>"$TMP/$r.err"; then
    echo "   DIFF  Argo has no Application $r"
    differences=$((differences + 1)); continue
  fi
  jq -r '.status.resources[]? | select(.hook != true) | ((.kind | ascii_downcase) + (if (.group // "") != "" then "." + .group else "" end)) + "|" + .name' \
    "$TMP/$r.app" | sort -u >"$TMP/$r.argo.list"
  if ! diff -u --label "flux objects" --label "argo objects" "$TMP/$r.flux.list" "$TMP/$r.argo.list" >"$TMP/$r.list.diff"; then
    echo "   DIFF  object lists differ"
    sed 's/^/      /' "$TMP/$r.list.diff"
    differences=$((differences + 1))
  fi
  while IFS='|' read -r res name; do
    compare_object "$res" "$name" "$ns"
  done < <(sort -u "$TMP/$r.flux.list" "$TMP/$r.argo.list")
done

echo "compared $compared object(s), $differences difference(s), $expected expected difference(s)"
(( differences == 0 ))
