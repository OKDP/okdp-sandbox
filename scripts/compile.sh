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

# Compiles the sources of the layout (platform/, projects/) with okdp-gitops compile,
# the service catalogs of platform/catalog.yaml read from git: what the console does
# for each change it commits, for the whole layout. The compiled tree is never written
# here: it goes to the output directory, the content of the output repository at its
# root (compiled/, flux/ with the generated components.yaml, argocd/), the same in
# every topology. scripts/configure.sh --push compiles the committed layout the same
# way and pushes it to Forgejo; run this script to see what it would deploy, or to
# check that the layout compiles after editing it.
#
#   --output DIR       write the output tree into DIR (its flux/ and argocd/ replaced
#                      by the layout's, compiled/ rebuilt); without it, a temporary
#                      directory, removed at exit: the layout compiles or not. DIR may
#                      be --root, a layout holding its own output (a clone of the mono
#                      deployments repository): compiled in place.
#   --catalog NAME=SRC read catalog NAME from SRC instead (repeatable; OKDP_CATALOGS
#                      "NAME=SRC ..." too): a directory, read as it is (e.g. a checkout
#                      with uncommitted changes), or a Git URL read at the catalog's
#                      ref. Default: the checkout NAME next to this repository, read at
#                      the catalog's ref, else https://github.com/OKDP/NAME.git.
#   --work DIR         keep the catalogs read and the local topology file in DIR
#   -- ARGS...         more okdp-gitops compile arguments (OKDP_GITOPS_ARGS too)
#
# Usage: compile.sh [--root DIR] [--output DIR] [--catalog NAME=SRC]...
#                   [--work DIR] [-- ARGS...]
# Requires bash >= 4, yq v4, git, okdp-gitops (okdp-control-plane-server: make
# build-gitops; OKDP_GITOPS names it).

set -euo pipefail
export LC_ALL=C

PROG=compile
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS/../gitops" && pwd)"
OUTPUT=""
CATALOGS=()
EXTRA=()
WORK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    --output) OUTPUT="$(mkdir -p "$2" && cd "$2" && pwd)"; shift 2 ;;
    --catalog) CATALOGS+=("$2"); shift 2 ;;
    --work) WORK_DIR="$2"; shift 2 ;;
    --) shift; EXTRA+=("$@"); break ;;
    -h|--help) sed -n '18,43p' "$0"; exit 0 ;;
    *) echo "compile: unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v yq >/dev/null || { echo "compile: yq v4 is required" >&2; exit 2; }
command -v "${OKDP_GITOPS:-okdp-gitops}" >/dev/null \
  || { echo "compile: okdp-gitops is required (okdp-control-plane-server: make build-gitops; or set OKDP_GITOPS)" >&2; exit 2; }

# shellcheck source=lib/topology.sh
source "$SCRIPTS/lib/topology.sh"

work_init "$WORK_DIR"
catalog_sources_init "${CATALOGS[@]}"
catalogs_resolve
# Word splitting of OKDP_GITOPS_ARGS is intended.
# shellcheck disable=SC2206
EXTRA+=(${OKDP_GITOPS_ARGS:-})
layout_compile "${OUTPUT:-$WORK/output}" "${EXTRA[@]}"
if [[ -n "$OUTPUT" ]]; then
  echo "output: $OUTPUT (the content of $(forgejo_owner)/$(output_repo "$(topology_current)"), $(topology_current) topology)" >&2
fi
