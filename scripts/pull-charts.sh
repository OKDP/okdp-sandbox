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

# Fills a chart cache DIR with the upstream charts the compiled instances render, in
# the layout of okdp-compiler's chart cache (helm pull --untar -d
# DIR/<repository without its scheme>/<chart>-<version>, the chart in
# DIR/<repository>/<chart>-<version>/<chart>/): the dependencies of every compiled
# umbrella chart (compiled/**/Chart.yaml of the output tree --output DIR, written by
# scripts/compile.sh --output DIR; the OAuth client charts among them) and the plain
# charts of the instances (instance.yaml chart of the layout).
# For scripts/check.sh --helm --charts DIR: helm template renders the compiled
# umbrellas without the network (and checks the values against each chart's
# values.schema.json); the same layout serves okdp-compile --check --charts DIR. The
# packages themselves are no charts to pull: they are read from the catalogs, in Git.
# A chart already in DIR is not pulled again; the public repositories need no
# credentials.
#
# Usage: pull-charts.sh [--root DIR] --output DIR DIR
# Requires bash >= 4, yq v4, helm.

set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS/../gitops" && pwd)"
CACHE=""
OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    --output) OUTPUT="$(cd "$2" && pwd)"; shift 2 ;;
    -h|--help) sed -n '18,33p' "$0"; exit 0 ;;
    -*) echo "pull-charts: unknown option: $1" >&2; exit 2 ;;
    *) CACHE="$1"; shift ;;
  esac
done
[[ -n "$CACHE" ]] || { echo "usage: pull-charts.sh [--root DIR] --output DIR DIR" >&2; exit 2; }
[[ -d "$OUTPUT/compiled" ]] \
  || { echo "pull-charts: --output DIR: an output tree with compiled/ (scripts/compile.sh --output DIR)" >&2; exit 2; }
mkdir -p "$CACHE"; CACHE="$(cd "$CACHE" && pwd)"

# "<repository>\t<chart>\t<version>" of every chart to cache.
charts() {
  local f
  while IFS= read -r f; do
    yq -r '.dependencies[]? | [.repository, .name, .version] | @tsv' "$f"
  done < <(find "$OUTPUT/compiled" -name Chart.yaml 2>/dev/null | sort)
  while IFS= read -r f; do
    # oci://<registry>/<path>/<chart>, or an https:// repository and service its chart.
    yq -r 'select(has("chart")) | select(.chart | test("^oci://")) | [(.chart | sub("/[^/]*$"; "")), (.chart | sub("^.*/"; "")), .version] | @tsv' "$f"
    yq -r 'select(has("chart")) | select(.chart | test("^https?://")) | [.chart, .service, .version] | @tsv' "$f"
  done < <(find "$ROOT/platform/components" "$ROOT/projects" -name instance.yaml 2>/dev/null | sort)
}

failures=0
while IFS=$'\t' read -r repo chart version; do
  [[ -n "$chart" ]] || continue
  repo="${repo%/}"
  dest="$CACHE/${repo#*://}/$chart-$version"
  [[ -f "$dest/$chart/Chart.yaml" ]] && continue
  case "$repo" in
    oci://*) source=("$repo/$chart") ;;
    http://*|https://*) source=("$chart" --repo "$repo") ;;
    *) echo "skipped $chart $version: repository '$repo' is not oci://, http:// or https://" >&2; continue ;;
  esac
  rm -rf "$dest"; mkdir -p "$dest"
  if helm pull "${source[@]}" --version "$version" --untar -d "$dest" >/dev/null 2>"$CACHE/.pull.log"; then
    echo "pulled $repo $chart $version"
  else
    echo "FAIL: $repo $chart $version: $(grep -v 'failed to load plugins' "$CACHE/.pull.log")" >&2
    rm -rf "$dest"
    failures=$((failures + 1))
  fi
done < <(charts | sort -u)
rm -f "$CACHE/.pull.log"
(( failures == 0 )) || { echo "pull-charts: $failures chart(s) not pulled" >&2; exit 1; }
