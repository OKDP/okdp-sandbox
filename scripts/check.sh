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

# CI check of the deployments layout (see gitops/README.md).
#
#   1. every YAML file parses;
#   2. platform-values.yaml, catalog.yaml (its repositories and its menu),
#      projects.yaml (the split topology), instance.yaml (a package of the catalogs,
#      or a plain chart) and connection files have the expected shape; flux/ and
#      argocd/ read the output repository of the topology; connection files match
#      their contract schema, from the contracts/ of the catalogs (one contract in two
#      catalogs must be the same file);
#   3. the layout compiles (as scripts/compile.sh does: okdp-gitops compile compiles
#      every instance with its package of the catalogs), into the output tree that
#      scripts/configure.sh --push would push (a temporary directory, or --output
#      DIR); nothing compiled is kept in the layout;
#   4. the kustomizations of that output build (when kustomize is installed);
#   5. with --helm: every compiled instance renders with `helm template`, which also
#      checks its values against each chart's values.schema.json: a package, the
#      umbrella chart compiled for it (its dependencies from the --charts DIR cache,
#      scripts/pull-charts.sh, else helm dependency build) with its
#      instance.values.yaml; a plain chart, from the cache or its registry, with its
#      compiled values.yaml.
# The catalogs are those of platform/catalog.yaml, read as scripts/compile.sh reads
# them (--catalog NAME=SRC, OKDP_CATALOGS; default: the checkouts next to this
# repository at the catalog's ref, else GitHub).
#
# Usage: check.sh [--root DIR] [--output DIR] [--catalog NAME=SRC]... [--charts DIR]
#                 [--helm]
# Requires bash >= 4, yq v4, jq, git, okdp-gitops (https://github.com/OKDP/okdp-gitops:
# make build; OKDP_GITOPS names it); optional: kustomize, helm.

set -euo pipefail
export LC_ALL=C

PROG=check
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS/../gitops" && pwd)"
HELM=false
CHARTS=""
OUTPUT=""
CATALOGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    --output) OUTPUT="$(mkdir -p "$2" && cd "$2" && pwd)"; shift 2 ;;
    --catalog) CATALOGS+=("$2"); shift 2 ;;
    --charts) CHARTS="$(cd "$2" && pwd)"; shift 2 ;;
    --helm) HELM=true; shift ;;
    -h|--help) sed -n '18,45p' "$0"; exit 0 ;;
    *) echo "check: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/topology.sh
source "$SCRIPTS/lib/topology.sh"

failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
step() { echo "== $*"; }
dns_label() { [[ "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; }

work_init ""
TMP="$WORK"
OUT="${OUTPUT:-$WORK/output}"

# ------------------------------------------------------------------ 1. YAML
step "YAML syntax"
# Not the Helm templates of the compiled umbrellas (templates/okdp.yaml: {{ .Files.Get }}).
while IFS= read -r f; do
  yq -e 'true' "$f" >/dev/null 2>&1 || [[ ! -s "$f" ]] || fail "${f#"$ROOT"/}: invalid YAML"
done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -path "$ROOT/compiled/*/templates" -prune \
  -o -type f \( -name '*.yaml' -o -name '*.yml' \) -print | sort)

# ------------------------------------------------------------- the catalogs
step "catalogs"
catalog_sources_init "${CATALOGS[@]}"
catalogs_resolve
# Contracts: the union of the catalogs' contracts/, the same file wherever repeated.
declare -A CONTRACTS=()
for name in $(printf '%s\n' "${!CATALOG_DIRS[@]}" | sort); do
  for f in "${CATALOG_DIRS[$name]}"/contracts/*.schema.json; do
    [[ -f "$f" ]] || continue
    c="${f##*/}"; c="${c%.schema.json}"
    if [[ -n "${CONTRACTS[$c]:-}" ]] && ! cmp -s "${CONTRACTS[$c]}" "$f"; then
      fail "contract $c differs between the catalogs (${CONTRACTS[$c]} and $f)"
    fi
    CONTRACTS[$c]="$f"
  done
done
echo "   contracts: $(printf '%s\n' "${!CONTRACTS[@]}" | sort | tr '\n' ' ')"
# catalog_package SERVICE [VERSION]: the catalog holding catalog/SERVICE[/VERSION].
catalog_package() {
  local name
  for name in "${!CATALOG_DIRS[@]}"; do
    if [[ -d "${CATALOG_DIRS[$name]}/catalog/$1${2:+/$2}" ]]; then echo "$name"; return 0; fi
  done
  return 1
}

# ----------------------------------------------------------------- 2. shapes
step "platform files"
pv="$ROOT/platform/platform-values.yaml"
if [[ ! -f "$pv" ]]; then
  fail "platform/platform-values.yaml is missing"
else
  [[ "$(yq '[keys[]] | join(",")' "$pv")" == "global" ]] || fail "platform/platform-values.yaml: the only top-level key is global"
  [[ "$(yq '.global | [keys[]] | join(",")' "$pv")" == "okdp" ]] || fail "platform/platform-values.yaml: the only key under global is okdp"
  [[ "$(yq '.global.okdp | has("serviceCatalog")' "$pv")" == "false" ]] || fail "platform/platform-values.yaml: serviceCatalog belongs in platform/catalog.yaml"
fi
cat="$ROOT/platform/catalog.yaml"
if [[ ! -f "$cat" ]]; then
  fail "platform/catalog.yaml is missing"
else
  [[ "$(yq 'has("defaultRepository")' "$cat")" == false ]] \
    || fail "platform/catalog.yaml: defaultRepository is gone, the packages come from the repositories"
  [[ "$(yq '.repositories | tag' "$cat")" == "!!seq" ]] || fail "platform/catalog.yaml: repositories must be a list"
  bad="$(yq '[.repositories[]? | select((.name | tag) != "!!str" or (.url | tag) != "!!str" or (.ref | tag) != "!!str")] | length' "$cat")"
  [[ "$bad" == "0" ]] || fail "platform/catalog.yaml: every repository needs name, url and ref (strings)"
  dup="$(yq -r '[.repositories[]?.name] | group_by(.) | map(select(length > 1) | .[0]) | join(" ")' "$cat")"
  [[ -z "$dup" ]] || fail "platform/catalog.yaml: repositories named twice: $dup"
  [[ "$(yq '.categories | tag' "$cat")" == "!!seq" ]] || fail "platform/catalog.yaml: categories must be a list"
  bad="$(yq '[.categories[] | select((.title | tag) != "!!str" or (.services | tag) != "!!seq")] | length' "$cat")"
  [[ "$bad" == "0" ]] || fail "platform/catalog.yaml: every category needs a title and a services list"
  bad="$(yq '[.categories[].services[] | select((.name | tag) != "!!str" or has("versions") or has("repository") or (has("default") and (.default | tag) != "!!str"))] | length' "$cat")"
  [[ "$bad" == "0" ]] || fail "platform/catalog.yaml: a service has a name and maybe a default version (a string); its versions are its catalog's directories"
  while IFS=$'\t' read -r s def; do
    if ! catalog_package "$s" >/dev/null; then
      fail "platform/catalog.yaml: service $s is in no catalog"
    elif [[ -n "$def" ]] && ! catalog_package "$s" "$def" >/dev/null; then
      fail "platform/catalog.yaml: service $s has no version $def"
    fi
  done < <(yq -r '.categories[].services[] | [.name, .default // ""] | @tsv' "$cat")
fi

step "topology ($(topology_current))"
topology="$(topology_current)"
[[ -z "$(yq '.gitops.path // ""' "$SERVER_VALUES" | tr -d /)" ]] \
  || fail "${SERVER_VALUES#"$ROOT"/}: gitops.path is set, the layout is at the root of its repositories"
[[ "$(entry_url)" == "$(output_url "$topology")" ]] \
  || fail "flux/ and argocd/ read $(entry_url), not the output repository of the $topology topology: scripts/configure.sh --topology $topology"
[[ -z "$(entry_prefix)" ]] \
  || fail "flux/sync.yaml: the paths start with $(entry_prefix), the output is at the root of its repository (./flux, ./compiled/...)"
if [[ "$topology" == split ]]; then
  if [[ ! -f "$PROJECTS_FILE" ]]; then
    fail "platform/projects.yaml is missing (split topology: scripts/configure.sh --topology split)"
  else
    listed="$(yq -r '.projects[]?.name' "$PROJECTS_FILE" | sort)"
    for p in $listed; do
      dns_label "$p" || fail "platform/projects.yaml: invalid project name '$p'"
    done
    [[ "$listed" == "$(project_names)" ]] \
      || fail "platform/projects.yaml lists '$(tr '\n' ' ' <<<"$listed")', projects/ holds '$(project_names | tr '\n' ' ')'"
  fi
elif [[ -f "$PROJECTS_FILE" ]]; then
  fail "platform/projects.yaml belongs to the split topology only ($topology here)"
fi

step "instances"
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  extra="$(yq '[keys[] | select(. != "name" and . != "project" and . != "service" and . != "chart" and . != "version" and . != "connections")] | join(",")' "$f")"
  [[ -z "$extra" ]] || fail "$rel: unknown keys $extra (name, project, service or chart, version, connections)"
  [[ "$(yq 'has("name") and has("project") and has("version")' "$f")" == true ]] \
    || fail "$rel: name, project and version are required"
  service="$(yq '.service // ""' "$f")"; version="$(yq '.version // ""' "$f")"
  if [[ "$(yq 'has("chart")' "$f")" == true ]]; then
    # A plain chart: oci://<registry>/<path>/<chart> (service, when set, the chart's
    # name), or https://<repository> with service the chart's name.
    chart="$(yq '.chart' "$f")"
    if [[ "$chart" =~ ^oci://[a-z0-9]([-a-z0-9.]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([-a-z0-9._]*[a-z0-9])?)+$ ]]; then
      [[ -z "$service" || "$chart" == */"$service" ]] || fail "$rel: chart must end with /$service"
    elif [[ "$chart" =~ ^https://[^[:space:]]+$ ]]; then
      [[ -n "$service" ]] || fail "$rel: a chart of an https:// repository needs service, the chart's name"
    else
      fail "$rel: chart must be an oci:// chart reference or an https:// repository"
    fi
  else
    [[ -n "$service" ]] || fail "$rel: a package instance names its service (or a plain chart, chart)"
    if [[ ${#CATALOG_DIRS[@]} -gt 0 ]] && ! catalog_package "$service" "$version" >/dev/null; then
      fail "$rel: no package $service $version in the catalogs (catalog/$service/$version/)"
    fi
  fi
done < <(find "$ROOT/projects" "$ROOT/platform/components" "$ROOT/optional" -name instance.yaml 2>/dev/null | sort)

step "connections (platform and projects)"
# check_connection FILE: one connection file ({connections: {<c>: {...}}}).
check_connection() {
  local f="$1" rel c contract schema fields problems m
  rel="${f#"$ROOT"/}"; c="${f##*/}"; c="${c%.yaml}"
  [[ "$(yq '[keys[]] | join(",")' "$f")" == "connections" ]] || { fail "$rel: the only top-level key is connections"; return; }
  [[ "$(yq '.connections | [keys[]] | join(",")' "$f")" == "$c" ]] || { fail "$rel: must define exactly connections.$c"; return; }
  contract="$(yq ".connections[\"$c\"].contract" "$f")"
  schema="${CONTRACTS[$contract]:-}"
  [[ -n "$schema" ]] || { fail "$rel: contract '$contract' is in no catalog's contracts/"; return; }
  # secretRef only for contracts with secret fields (the others have no Secret).
  if [[ "$(jq '[.properties[]? | select(.["x-okdp-secret"] == true)] | length' "$schema")" != "0" ]]; then
    [[ "$(yq ".connections[\"$c\"].secretRef.name | tag" "$f")" == "!!str" ]] || fail "$rel: secretRef.name is required"
  fi
  fields="$(yq -o=json ".connections[\"$c\"] | del(.contract) | del(.secretRef)" "$f")"
  # unknown fields, secret fields present, required non-secret fields missing
  problems="$(jq -rn --argjson v "$fields" --slurpfile s "$schema" '
    ($s[0].properties // {}) as $props
    | [ ($v | keys[]) as $k
        | if ($props | has($k)) | not then "unknown field \($k)"
          elif $props[$k]["x-okdp-secret"] == true then "secret field \($k) must be in the Secret, not here"
          else empty end ]
      + [ ($s[0].required // [])[] as $r
          | select(($props[$r]["x-okdp-secret"] // false) == false)
          | select(($v | has($r)) | not) | "missing required field \($r)" ]
    | .[]')"
  while IFS= read -r m; do [[ -z "$m" ]] || fail "$rel: $m"; done <<<"$problems"
}

for f in "$ROOT"/platform/connections/*.yaml "$ROOT"/projects/*/connections/*.yaml; do
  [[ -f "$f" ]] && check_connection "$f"
done

# ------------------------------------------------------------- 3. compile
step "the layout compiles (okdp-gitops compile, into ${OUTPUT:-a temporary output tree})"
compiled=false
if ! command -v "${OKDP_GITOPS:-okdp-gitops}" >/dev/null; then
  fail "okdp-gitops is required (https://github.com/OKDP/okdp-gitops: make build; or set OKDP_GITOPS)"
elif ! layout_compile "$OUT" >"$TMP/.compile.log" 2>&1; then
  sed 's/^/   /' "$TMP/.compile.log"
  fail "the layout does not compile"
else
  compiled=true
  echo "   $(find "$OUT/compiled" -type f | wc -l) files in compiled/"
fi

# ------------------------------------------------------------ 4. kustomize
if ! $compiled; then
  step "kustomize build: skipped (nothing compiled)"
elif command -v kustomize >/dev/null; then
  step "kustomize build"
  dirs=("$OUT/flux" "$OUT/compiled/platform")
  for d in "$OUT"/compiled/projects/*/ "$OUT"/compiled/platform/components/*/; do
    [[ -f "$d/kustomization.yaml" ]] && dirs+=("${d%/}")
  done
  for d in "${dirs[@]}"; do
    kustomize build "$d" >/dev/null 2>"$TMP/.kustomize.log" \
      || { fail "kustomize build ${d#"$OUT"/}"; sed 's/^/   /' "$TMP/.kustomize.log"; }
  done
else
  step "kustomize build: skipped (kustomize not installed)"
fi

# ----------------------------------------------------------------- 5. helm
# cached REPOSITORY NAME VERSION: the chart in the --charts cache (the layout of
# okdp-compiler's chart cache: <repository without scheme>/<name>-<version>/<name>).
cached() {
  local d="$CHARTS/${1#*://}"; d="${d%/}/$2-$3/$2"
  [[ -n "$CHARTS" && -f "$d/Chart.yaml" ]] && echo "$d"
}

if $HELM && ! $compiled; then
  step "helm template: skipped (nothing compiled)"
elif $HELM; then
  step "helm template of the compiled instances"
  command -v helm >/dev/null || { fail "--helm needs helm"; }
  while IFS= read -r inst; do
    dir="$(dirname "$inst")"; rel="${dir#"$ROOT"/}"; out="$OUT/compiled/$rel"
    name="$(yq '.name' "$inst")"; project="$(yq '.project' "$inst")"
    if [[ -f "$out/Chart.yaml" ]]; then
      # A package: the umbrella, its dependencies from the cache or their repositories.
      chart="$TMP/umbrella/$project-$name"
      rm -rf "$chart"; mkdir -p "$chart"; cp -R "$out/." "$chart"; rm -rf "$chart/charts" "$chart/Chart.lock"
      missing=false
      while IFS=$'\t' read -r repo dep version; do
        if src="$(cached "$repo" "$dep" "$version")"; then
          mkdir -p "$chart/charts"; rm -rf "$chart/charts/$dep-$version"; cp -R "$src" "$chart/charts/$dep-$version"
        else
          missing=true
        fi
      done < <(yq -r '.dependencies[]? | [.repository, .name, .version] | @tsv' "$out/Chart.yaml")
      if $missing; then
        rm -rf "$chart/charts"
        helm dependency build "$chart" >"$TMP/.helm.log" 2>&1 \
          || { fail "helm dependency build $rel"; grep -v 'failed to load plugins' "$TMP/.helm.log" | sed 's/^/   /'; continue; }
      fi
      source=("$chart") values="$out/instance.values.yaml"
    elif [[ "$(yq 'has("chart")' "$inst")" != true ]]; then
      fail "helm template $rel: no compiled umbrella chart (compiled/$rel/Chart.yaml)"
      continue
    else
      # A plain chart, from the cache or its registry.
      ref="$(yq '.chart' "$inst")"; version="$(yq '.version' "$inst")"
      if [[ "$ref" == oci://* ]]; then
        repo="${ref%/*}" dep="${ref##*/}" source=("$ref" --version "$version")
      else
        repo="$ref" dep="$(yq '.service' "$inst")"; source=("$dep" --repo "$ref" --version "$version")
      fi
      if src="$(cached "$repo" "$dep" "$version")"; then source=("$src"); fi
      values="$out/values.yaml"
    fi
    if helm template "$project-$name" "${source[@]}" -n "$project" -f "$values" >"$TMP/.helm.out" 2>"$TMP/.helm.log"; then
      echo "   ok $rel ($(grep -c '^kind:' "$TMP/.helm.out") objects)"
    else
      fail "helm template $rel"; grep -v 'failed to load plugins' "$TMP/.helm.log" | sed 's/^/   /'
    fi
  done < <(find "$ROOT/projects" "$ROOT/platform/components" -name instance.yaml 2>/dev/null | sort)
fi

if (( failures > 0 )); then
  echo "check: $failures failure(s)" >&2
  exit 1
fi
echo "check: OK"
