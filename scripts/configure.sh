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

# Configures the sandbox (gitops/README.md, "Topologies"), in two steps.
#
# 1. Choose, in the layout only (nothing is applied; commit the result):
#   --engine flux|argocd        gitops.engine of 30-okdp-control-plane-server (the
#                               console writes for that engine);
#   --storage seaweedfs|rustfs  the package of 20-storage. The active store lives in
#                               platform/components/20-storage, the others are parked
#                               in optional/storage/<store> (instance.yaml, values.yaml):
#                               the two are swapped, the internalUrl of the connection
#                               files pointing at the store is rewritten;
#   --topology mono|io|split    the Forgejo repositories of the parts: mono one
#                               deployments repository (okdp/okdp-deployments:
#                               platform/, projects/, compiled/, flux/, argocd/); io
#                               okdp/okdp-input (platform/, projects/) and
#                               okdp/okdp-output (compiled/, flux/, argocd/); split
#                               okdp/okdp-platform, one okdp/okdp-project-<p> per
#                               project and okdp/okdp-output. Writes gitops.topology
#                               (and, split, gitops.forgejoTokenSecret) of the server,
#                               points flux/ and argocd/ at the output repository,
#                               writes (split) or removes platform/projects.yaml.
#   Without a choice on a terminal, or with -i, asks for the three (the current values
#   are the defaults). Choose before the first install: switching the store of a
#   running sandbox starts from an empty store, switching engines or topologies means
#   reinstalling.
#
# 2. --push: puts the committed layout (HEAD) on the sandbox's Forgejo (20-forgejo
#   installed, README step 3; current kubectl context, port-forward, or FORGEJO_URL):
#   compiles it into the output tree (as scripts/compile.sh does; nothing is pushed
#   when it does not compile), creates the organization okdp and the repositories of
#   the topology (public), registers the CI runner (30-forgejo-runner) for the
#   organization, copies the service catalogs of platform/catalog.yaml (their
#   ref, from --catalog, else the checkouts next to this repository, else GitHub),
#   pushes each part, the sources then the output, as one commit on top of the
#   repository's main (refused when the console committed there since the last push;
#   --force replaces the console's changes), and, split, creates an access token of
#   the Forgejo admin for the server, in the Secret gitops.forgejoTokenSecret of its
#   namespace. --dry-run compiles, prints what it would push and keeps the parts (in
#   --work DIR, or a printed directory).
#
# Usage: configure.sh [-i|--interactive] [--engine flux|argocd]
#                     [--storage seaweedfs|rustfs] [--topology mono|io|split]
#                     [--root DIR]
#        configure.sh --push [--force] [--dry-run] [--work DIR] [--catalog NAME=SRC]...
#        configure.sh --show
# --catalog NAME=SRC: see scripts/compile.sh. Requires bash >= 4, yq v4; --push also
# git, okdp-gitops (https://github.com/OKDP/okdp-gitops: make build; OKDP_GITOPS names
# it, OKDP_GITOPS_ARGS adds arguments), curl, jq and kubectl.

set -euo pipefail
export LC_ALL=C

PROG=configure
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS/../gitops" && pwd)"
ENGINE=""
STORAGE=""
TOPOLOGY=""
INTERACTIVE=false
SHOW=false
PUSH=false
FORCE=false
DRY_RUN=false
WORK_DIR=""
CATALOGS=()

ENGINES=(flux argocd)
STORES=(seaweedfs rustfs)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) ENGINE="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --topology) TOPOLOGY="$2"; shift 2 ;;
    -i|--interactive) INTERACTIVE=true; shift ;;
    --show) SHOW=true; shift ;;
    --push) PUSH=true; shift ;;
    --force) FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --work) WORK_DIR="$2"; shift 2 ;;
    --catalog) CATALOGS+=("$2"); shift 2 ;;
    --root) ROOT="$(cd "$2" && pwd)"; shift 2 ;;
    -h|--help) sed -n '18,64p' "$0"; exit 0 ;;
    *) echo "configure: unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v yq >/dev/null || { echo "configure: yq v4 is required" >&2; exit 2; }
yq --version 2>&1 | grep -q 'version v4' || { echo "configure: yq v4 (mikefarah) is required" >&2; exit 2; }

# shellcheck source=lib/topology.sh
source "$SCRIPTS/lib/topology.sh"

STORE_DIR="$ROOT/platform/components/20-storage"
PARKED="$ROOT/optional/storage"

# In-cluster S3 endpoint of a store: store release namespace.
internal_url() {
  case "$1" in
    seaweedfs) echo "http://$2-s3.$3.svc.cluster.local:8333" ;;
    rustfs) echo "http://$2-svc.$3.svc.cluster.local:9000" ;;
  esac
}

CUR_ENGINE="$(yq '.gitops.engine // ""' "$SERVER_VALUES")"
CUR_STORAGE="$(yq '.service // ""' "$STORE_DIR/instance.yaml")"
CUR_TOPOLOGY="$(topology_current)"
one_of "$CUR_ENGINE" "${ENGINES[@]}" \
  || die "unexpected gitops.engine '$CUR_ENGINE' in ${SERVER_VALUES#"$ROOT"/}"
one_of "$CUR_STORAGE" "${STORES[@]}" \
  || die "unexpected service '$CUR_STORAGE' in ${STORE_DIR#"$ROOT"/}/instance.yaml"

if $SHOW; then
  echo "engine:   $CUR_ENGINE"
  echo "storage:  $CUR_STORAGE"
  echo "topology: $CUR_TOPOLOGY"
  topology_describe "$CUR_TOPOLOGY"
  echo "Flux and Argo CD read $(entry_url)"
  exit 0
fi

# ---------------------------------------------------------------------- push

# part DEST TREE [PATHS...]: the committed files (HEAD) of TREE, a directory of this
# repository ("" for its root), or only its PATHS, into DEST.
part() {
  local dest="$1" tree="$2"; shift 2
  rm -rf "$dest"; mkdir -p "$dest"
  git -C "$TOP" archive "HEAD:$tree" "$@" | tar -x -C "$dest"
}

push() {
  local owner prefix sha message p force=() out
  # shellcheck source=lib/forgejo.sh
  source "$SCRIPTS/lib/forgejo.sh"
  TOP="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" \
    || die "--push sends the committed layout: $ROOT is not in a Git repository"
  [[ -z "$(git -C "$ROOT" status --porcelain -- .)" ]] \
    || die "uncommitted changes in $ROOT: commit them first (--push sends HEAD)"
  command -v "${OKDP_GITOPS:-okdp-gitops}" >/dev/null \
    || die "okdp-gitops is required to compile the layout (https://github.com/OKDP/okdp-gitops: make build; or set OKDP_GITOPS)"
  mono_check
  prefix="$(git -C "$ROOT" rev-parse --show-prefix)"; prefix="${prefix%/}"
  sha="$(git -C "$TOP" rev-parse --short HEAD)"
  message="okdp-sandbox $sha: $(git -C "$TOP" log -1 --format=%s)"
  owner="$(forgejo_owner)"
  if $FORCE; then force=(--force); fi

  if $DRY_RUN && [[ -z "$WORK_DIR" ]]; then WORK_DIR="$(mktemp -d)"; fi
  work_init "$WORK_DIR"
  catalog_sources_init "${CATALOGS[@]}"

  # The committed layout, compiled into the tree of the output repository.
  echo "Compiling $sha ($CUR_TOPOLOGY topology)"
  part "$WORK/layout" "$prefix"
  catalogs_resolve
  out="$WORK/parts/$(output_repo "$CUR_TOPOLOGY")"
  rm -rf "$out"
  # Word splitting of OKDP_GITOPS_ARGS is intended.
  # shellcheck disable=SC2086
  (ROOT="$WORK/layout"; layout_compile "$out" ${OKDP_GITOPS_ARGS:-}) >"$WORK/compile.log" 2>&1 \
    || { cat "$WORK/compile.log" >&2; die "the layout does not compile: nothing pushed"; }
  echo "compiled: $(find "$out/compiled" -type f | wc -l) files in compiled/, flux/components.yaml"

  echo "Pushing $sha, $CUR_TOPOLOGY topology, to Forgejo"
  forgejo_init
  forgejo_connect
  forgejo_ensure_org "$owner"
  forgejo_register_runner "$owner"
  forgejo_push_catalogs

  case "$CUR_TOPOLOGY" in
    mono)
      # One repository: the sources next to the output.
      for p in platform projects; do
        if [[ -d "$WORK/layout/$p" ]]; then cp -R "$WORK/layout/$p" "$out/"; fi
      done
      forgejo_ci_workflow "$out"
      forgejo_ensure_repo "$owner" "$(mono_repo)" "OKDP deployments repository: the sources and the compiled tree (mono topology)"
      forgejo_enable_actions "$owner" "$(mono_repo)"
      ;;
    io)
      part "$WORK/parts/$INPUT_REPO" "$prefix" platform projects
      forgejo_ci_workflow "$WORK/parts/$INPUT_REPO"
      forgejo_ensure_repo "$owner" "$INPUT_REPO" "OKDP sources: platform/, projects/ (io topology)"
      forgejo_enable_actions "$owner" "$INPUT_REPO"
      forgejo_push_tree "$WORK/parts/$INPUT_REPO" "$owner" "$INPUT_REPO" "$message" "${force[@]}"
      ;;
    split)
      part "$WORK/parts/$PLATFORM_REPO" "${prefix:+$prefix/}platform"
      forgejo_ci_workflow "$WORK/parts/$PLATFORM_REPO"
      forgejo_ensure_repo "$owner" "$PLATFORM_REPO" "OKDP platform sources (split topology)"
      forgejo_enable_actions "$owner" "$PLATFORM_REPO"
      forgejo_push_tree "$WORK/parts/$PLATFORM_REPO" "$owner" "$PLATFORM_REPO" "$message" "${force[@]}"
      for p in $(yq '.projects[].name' "$PROJECTS_FILE"); do
        [[ -d "$ROOT/projects/$p" ]] || die "platform/projects.yaml lists $p, projects/$p does not exist"
        part "$WORK/parts/$PROJECT_REPO_PREFIX$p" "${prefix:+$prefix/}projects/$p"
        forgejo_ci_workflow "$WORK/parts/$PROJECT_REPO_PREFIX$p"
        forgejo_ensure_repo "$owner" "$PROJECT_REPO_PREFIX$p" "OKDP project $p (split topology)"
        forgejo_enable_actions "$owner" "$PROJECT_REPO_PREFIX$p"
        forgejo_push_tree "$WORK/parts/$PROJECT_REPO_PREFIX$p" "$owner" "$PROJECT_REPO_PREFIX$p" "$message" "${force[@]}"
      done
      ;;
  esac
  if [[ "$CUR_TOPOLOGY" != mono ]]; then
    forgejo_ensure_repo "$owner" "$OUTPUT_REPO" "OKDP compiled tree, read by Flux and Argo CD ($CUR_TOPOLOGY topology)"
  fi
  forgejo_push_tree "$out" "$owner" "$(output_repo "$CUR_TOPOLOGY")" "$message" "${force[@]}"
  if [[ "$CUR_TOPOLOGY" == split ]]; then
    forgejo_token_secret "$(yq '.project' "$SERVER_COMPONENT/instance.yaml")" \
      "$(yq '.gitops.forgejoTokenSecret // ""' "$SERVER_VALUES")"
  fi
  if $DRY_RUN; then
    echo "Dry run: nothing pushed; the parts are in $WORK/parts"
    return
  fi
  cat <<EOF

Next: install $([[ "$CUR_ENGINE" == flux ]] && echo "Flux (README, step 4a)" || echo "Argo CD (README, step 4b)");
it reads $(entry_url).
EOF
}

if $PUSH; then
  if [[ -n "$ENGINE$STORAGE$TOPOLOGY" ]] || $INTERACTIVE; then
    die "--push sends the committed layout: configure, commit, then push (two runs)"
  fi
  push
  exit 0
fi

# ----------------------------------------------------------------- configure

# Numbered menu on stderr; prints the choice. Enter keeps the default.
ask() { # prompt default choices...
  local prompt="$1" def="$2"; shift 2
  local i reply
  echo "$prompt" >&2
  i=1
  for c in "$@"; do
    printf '  %d) %s%s\n' "$i" "$c" "$([[ "$c" == "$def" ]] && echo ' (current)')" >&2
    i=$((i + 1))
  done
  while true; do
    read -r -p "Choice [$def]: " reply </dev/tty >&2 || exit 1
    [[ -z "$reply" ]] && { echo "$def"; return; }
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= $# )); then
      echo "${!reply}"; return
    fi
    one_of "$reply" "$@" && { echo "$reply"; return; }
    echo "  answer 1-$#, a name, or Enter" >&2
  done
}

if [[ -z "$ENGINE" && -z "$STORAGE" && -z "$TOPOLOGY" && -t 0 ]]; then
  INTERACTIVE=true
fi
if $INTERACTIVE; then
  [[ -r /dev/tty ]] || { echo "configure: --interactive needs a terminal" >&2; exit 2; }
  [[ -n "$ENGINE" ]] || ENGINE="$(ask "GitOps engine:" "$CUR_ENGINE" "${ENGINES[@]}")"
  [[ -n "$STORAGE" ]] || STORAGE="$(ask "Object store (20-storage):" "$CUR_STORAGE" "${STORES[@]}")"
  if [[ -z "$TOPOLOGY" ]]; then
    echo "Repositories: mono, one deployments repository; io, an input and an output" >&2
    echo "repository; split, a platform repository, one per project and an output one." >&2
    TOPOLOGY="$(ask "Topology:" "$CUR_TOPOLOGY" "${TOPOLOGIES[@]}")"
  fi
  echo >&2
  echo "engine:   $CUR_ENGINE -> $ENGINE" >&2
  echo "storage:  $CUR_STORAGE -> $STORAGE" >&2
  echo "topology: $CUR_TOPOLOGY -> $TOPOLOGY" >&2
  if [[ "$ENGINE" == "$CUR_ENGINE" && "$STORAGE" == "$CUR_STORAGE" && "$TOPOLOGY" == "$CUR_TOPOLOGY" ]]; then
    echo "Nothing to change." >&2
    exit 0
  fi
  read -r -p "Apply? [Y/n] " reply </dev/tty >&2 || exit 1
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]] || { echo "Aborted." >&2; exit 1; }
fi

if [[ -z "$ENGINE" && -z "$STORAGE" && -z "$TOPOLOGY" ]]; then
  echo "configure: nothing to do (--engine, --storage, --topology, -i, --push or --show; --help)" >&2
  exit 2
fi
ENGINE="${ENGINE:-$CUR_ENGINE}"
STORAGE="${STORAGE:-$CUR_STORAGE}"
TOPOLOGY="${TOPOLOGY:-$CUR_TOPOLOGY}"
one_of "$ENGINE" "${ENGINES[@]}" || { echo "configure: --engine: one of ${ENGINES[*]}" >&2; exit 2; }
one_of "$STORAGE" "${STORES[@]}" || { echo "configure: --storage: one of ${STORES[*]}" >&2; exit 2; }
one_of "$TOPOLOGY" "${TOPOLOGIES[@]}" || { echo "configure: --topology: one of ${TOPOLOGIES[*]}" >&2; exit 2; }

changed=false

if [[ "$ENGINE" != "$CUR_ENGINE" ]]; then
  # Line edit, so that the file keeps its comments and layout byte for byte.
  sed -i -E "s/^(  engine: )$CUR_ENGINE\$/\1$ENGINE/" "$SERVER_VALUES"
  [[ "$(yq '.gitops.engine' "$SERVER_VALUES")" == "$ENGINE" ]] \
    || die "could not set gitops.engine in ${SERVER_VALUES#"$ROOT"/}"
  echo "engine: $CUR_ENGINE -> $ENGINE (${SERVER_VALUES#"$ROOT"/})"
  changed=true
fi

if [[ "$STORAGE" != "$CUR_STORAGE" ]]; then
  [[ -f "$PARKED/$STORAGE/instance.yaml" && -f "$PARKED/$STORAGE/values.yaml" ]] \
    || die "${PARKED#"$ROOT"/}/$STORAGE/{instance,values}.yaml missing"
  [[ ! -e "$PARKED/$CUR_STORAGE" ]] \
    || die "${PARKED#"$ROOT"/}/$CUR_STORAGE already exists, cannot park the current store"

  name="$(yq '.name' "$STORE_DIR/instance.yaml")"
  project="$(yq '.project' "$STORE_DIR/instance.yaml")"
  old_url="$(internal_url "$CUR_STORAGE" "$project-$name" "$project")"
  new_url="$(internal_url "$STORAGE" "$project-$name" "$project")"

  mkdir -p "$PARKED/$CUR_STORAGE"
  mv "$STORE_DIR/instance.yaml" "$STORE_DIR/values.yaml" "$PARKED/$CUR_STORAGE/"
  mv "$PARKED/$STORAGE/instance.yaml" "$PARKED/$STORAGE/values.yaml" "$STORE_DIR/"
  rmdir "$PARKED/$STORAGE"
  echo "storage: $CUR_STORAGE -> $STORAGE (${STORE_DIR#"$ROOT"/}; $CUR_STORAGE parked in ${PARKED#"$ROOT"/}/$CUR_STORAGE)"

  while IFS= read -r f; do
    OLD="$old_url" NEW="$new_url" yq -i \
      '(.connections[] | select(.internalUrl == strenv(OLD)) | .internalUrl) = strenv(NEW)' "$f"
    echo "  internalUrl -> $new_url (${f#"$ROOT"/})"
  done < <(grep -rlF --include='*.yaml' "$old_url" "$ROOT/projects" "$ROOT/platform/connections" 2>/dev/null | sort)
  changed=true
fi

if [[ "$TOPOLOGY" != "$CUR_TOPOLOGY" ]]; then
  topology_set "$TOPOLOGY"
  echo "topology: $CUR_TOPOLOGY -> $TOPOLOGY (${SERVER_VALUES#"$ROOT"/})"
  changed=true
fi
# The entry points, the CI runner's topology and platform/projects.yaml follow the
# topology (also after a hand edit of the server's values).
if entry_points_retarget "$(output_url "$TOPOLOGY")"; then
  echo "  flux/, argocd/ -> $(entry_url)"
  changed=true
fi
if runner_topology_set "$TOPOLOGY"; then
  echo "  ${RUNNER_VALUES#"$ROOT"/}: topology $TOPOLOGY"
  changed=true
fi
if projects_file_set "$TOPOLOGY"; then
  if [[ -f "$PROJECTS_FILE" ]]; then
    echo "  ${PROJECTS_FILE#"$ROOT"/}: $(project_names | tr '\n' ' ')"
  else
    echo "  ${PROJECTS_FILE#"$ROOT"/}: removed"
  fi
  changed=true
fi

if $changed; then
  cat <<EOF

Next: review and commit, then put it on Forgejo with scripts/configure.sh --push, which
compiles it (README, step 3); then install $([[ "$ENGINE" == flux ]] && echo "Flux (README, step 4a)." || echo "Argo CD (README, step 4b).")
EOF
else
  echo "Already engine=$ENGINE storage=$STORAGE topology=$TOPOLOGY; nothing changed."
fi
