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

# Sourced by the scripts in scripts/, after lib/topology.sh: the sandbox's
# Forgejo (20-forgejo), reached through a kubectl port-forward of the current
# context (KUBECONFIG), or at FORGEJO_URL when set (e.g. http://localhost:3000), with
# the admin account of the component's values. Its API creates the organization and
# the repositories; git pushes with the same account, through GIT_ASKPASS (never in a
# URL or on a command line). With DRY_RUN=true, nothing is called: each action is
# printed, the parts are still built in $WORK.
#
# Requires curl, jq, kubectl (port-forward, the token Secret, the runner's
# registration), git.

FORGEJO_COMPONENT="$ROOT/platform/components/20-forgejo"
SECRETS_VALUES="$ROOT/platform/components/10-local-secrets-provider/values.yaml"
DRY_RUN="${DRY_RUN:-false}"

dry() { echo "[dry-run] $*"; }

# forgejo_init: the admin account and the Service of 20-forgejo.
forgejo_init() {
  FORGEJO_USER="$(yq '.gitea.admin.username' "$FORGEJO_COMPONENT/values.yaml")"
  FORGEJO_PASSWORD="$(yq '.gitea.admin.password' "$FORGEJO_COMPONENT/values.yaml")"
  FORGEJO_NAMESPACE="$(yq '.project' "$FORGEJO_COMPONENT/instance.yaml")"
  FORGEJO_DEPLOYMENT="$(yq '.fullnameOverride // "forgejo"' "$FORGEJO_COMPONENT/values.yaml")"
  FORGEJO_SERVICE="$FORGEJO_DEPLOYMENT-http"
  FORGEJO_BODY="$WORK/forgejo.response"
  FORGEJO_ASKPASS="$WORK/askpass.sh"
  cat >"$FORGEJO_ASKPASS" <<'ASKPASS'
#!/bin/sh
case "$1" in
  Username*) printf '%s\n' "$OKDP_FORGEJO_USER" ;;
  *) printf '%s\n' "$OKDP_FORGEJO_PASSWORD" ;;
esac
ASKPASS
  chmod 700 "$FORGEJO_ASKPASS"
}

# forgejo_connect: FORGEJO, the URL of Forgejo from here: FORGEJO_URL, or a
# port-forward of its Service (stopped at exit).
forgejo_connect() {
  local port=""
  if [[ -n "${FORGEJO_URL:-}" ]]; then
    FORGEJO="${FORGEJO_URL%/}"
  elif $DRY_RUN; then
    FORGEJO="http://127.0.0.1:<port>"
    dry "kubectl -n $FORGEJO_NAMESPACE port-forward svc/$FORGEJO_SERVICE 0:3000 (context $(kubectl config current-context 2>/dev/null || echo '?'))"
    return
  else
    echo "Forgejo: port-forward of $FORGEJO_NAMESPACE/svc/$FORGEJO_SERVICE (context $(kubectl config current-context))"
    kubectl -n "$FORGEJO_NAMESPACE" port-forward "svc/$FORGEJO_SERVICE" 0:3000 >"$WORK/port-forward.log" 2>&1 &
    FORGEJO_PF=$!
    # shellcheck disable=SC2016 # expanded at exit
    on_exit 'kill "$FORGEJO_PF" 2>/dev/null || true'
    for _ in $(seq 30); do
      port="$(sed -n 's/.*127.0.0.1:\([0-9]*\) ->.*/\1/p' "$WORK/port-forward.log" | head -n 1)"
      [[ -n "$port" ]] && break
      kill -0 "$FORGEJO_PF" 2>/dev/null || break
      sleep 1
    done
    [[ -n "$port" ]] || { cat "$WORK/port-forward.log" >&2; die "cannot port-forward to Forgejo (is 20-forgejo installed? README, step 3)"; }
    FORGEJO="http://127.0.0.1:$port"
  fi
  for _ in $(seq 30); do
    curl -sf -o /dev/null "$FORGEJO/api/v1/version" && return 0
    sleep 2
  done
  die "Forgejo does not answer at $FORGEJO"
}

curl_quote() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

# forgejo_api METHOD PATH [JSON]: calls the API as the admin (basic auth, given to
# curl as a config file, not on its command line); FORGEJO_STATUS is the HTTP
# status, the body is in FORGEJO_BODY.
forgejo_api() {
  local data=()
  [[ -z "${3:-}" ]] || data=(--data "$3")
  FORGEJO_STATUS="$(curl -sS -o "$FORGEJO_BODY" -w '%{http_code}' -X "$1" \
    -H 'Accept: application/json' -H 'Content-Type: application/json' \
    -K <(printf 'user = "%s:%s"\n' "$(curl_quote "$FORGEJO_USER")" "$(curl_quote "$FORGEJO_PASSWORD")") \
    "${data[@]}" "$FORGEJO/api/v1$2")" || FORGEJO_STATUS=000
}

forgejo_fail() { # MESSAGE
  echo "$PROG: $1: HTTP $FORGEJO_STATUS $(jq -r '.message? // empty' "$FORGEJO_BODY" 2>/dev/null || true)" >&2
  exit 1
}

# forgejo_ensure_org OWNER: the organization, created public if missing.
declare -A FORGEJO_ORGS=()
forgejo_ensure_org() {
  [[ -z "${FORGEJO_ORGS[$1]:-}" ]] || return 0
  FORGEJO_ORGS[$1]=1
  if $DRY_RUN; then dry "organization $1: created (public) if missing"; return; fi
  forgejo_api GET "/orgs/$1"
  case "$FORGEJO_STATUS" in
    200) ;;
    404)
      forgejo_api POST /orgs "$(jq -cn --arg o "$1" '{username: $o, visibility: "public"}')"
      [[ "$FORGEJO_STATUS" == 201 ]] \
        || forgejo_fail "cannot create the organization $1 (a user of that name, e.g. the admin of an older sandbox?)"
      echo "organization $1: created"
      ;;
    *) forgejo_fail "organization $1" ;;
  esac
}

# forgejo_ensure_repo OWNER NAME DESCRIPTION: the repository, created public and empty
# if missing.
forgejo_ensure_repo() {
  if $DRY_RUN; then dry "repository $1/$2: created (public) if missing"; return; fi
  forgejo_api GET "/repos/$1/$2"
  case "$FORGEJO_STATUS" in
    200)
      [[ "$(jq -r '.private' "$FORGEJO_BODY")" == false ]] \
        || echo "warning: $1/$2 is private: Flux, Argo CD and the console read the repositories anonymously" >&2
      ;;
    404)
      forgejo_api POST "/orgs/$1/repos" "$(jq -cn --arg n "$2" --arg d "$3" \
        '{name: $n, description: $d, private: false, default_branch: "main"}')"
      [[ "$FORGEJO_STATUS" == 201 ]] || forgejo_fail "cannot create the repository $1/$2"
      echo "repository $1/$2: created"
      ;;
    *) forgejo_fail "repository $1/$2" ;;
  esac
}

forgejo_repo_url() { echo "$FORGEJO/$1/$2.git"; }

# forgejo_enable_actions OWNER NAME: Forgejo Actions on for the repository (a
# repository of the sources: its workflow is the CI), also when it was created before
# Actions was enabled.
forgejo_enable_actions() {
  if $DRY_RUN; then dry "repository $1/$2: Actions enabled"; return; fi
  forgejo_api PATCH "/repos/$1/$2" '{"has_actions": true}'
  [[ "$FORGEJO_STATUS" == 200 ]] || forgejo_fail "cannot enable Actions in the repository $1/$2"
}

# forgejo_git ARGS...: git with the admin's credentials (GIT_ASKPASS), no credential
# helper, and an identity for the commits it writes when none is configured.
forgejo_git() {
  GIT_ASKPASS="$FORGEJO_ASKPASS" GIT_TERMINAL_PROMPT=0 \
    OKDP_FORGEJO_USER="$FORGEJO_USER" OKDP_FORGEJO_PASSWORD="$FORGEJO_PASSWORD" \
    GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-$(git config user.name || echo okdp-sandbox)}" \
    GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo okdp-sandbox@okdp.io)}" \
    GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$(git config user.name || echo okdp-sandbox)}" \
    GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$(git config user.email || echo okdp-sandbox@okdp.io)}" \
    git -c credential.helper= "$@"
}

# forgejo_push_ref SRC REV REF OWNER NAME [--force]: pushes commit REV of the Git
# repository SRC as REF (refs/heads/<b> or refs/tags/<t>) of OWNER/NAME.
forgejo_push_ref() {
  local src="$1" rev="$2" ref="$3" url commit force=()
  url="$(forgejo_repo_url "$4" "$5")"
  [[ "${6:-}" != --force ]] || force=(--force)
  commit="$(git -C "$src" rev-parse --verify "$rev^{commit}")"
  if $DRY_RUN; then dry "push $src $rev (${commit:0:12}) to $4/$5 $ref ${force[*]}"; return; fi
  [[ "$(git -C "$src" rev-parse --is-shallow-repository)" == false ]] \
    || die "$src is a shallow clone: Forgejo refuses its history (clone it without --depth)"
  forgejo_git -C "$src" push -q "${force[@]}" "$url" "$commit:$ref"
  echo "pushed $4/$5 $ref (${commit:0:12})"
}

# forgejo_push_tree DIR OWNER NAME MESSAGE [--force]: makes the files of DIR the
# content of branch main of OWNER/NAME: one commit on top of its main (none when
# nothing changed), whose history is kept. MESSAGE starts with "okdp-sandbox ": when
# main has, since its last such commit, a commit other than the CI's ("okdp: compile",
# 30-forgejo-runner: the compile of what was pushed), someone committed since the last
# push (the console, a person), and the push is refused, unless --force (their changes
# are then replaced). A push that loses the race against the CI (the compile of the
# sources pushed just before) is made again on top of the CI's commit.
forgejo_push_tree() {
  local dir="$1" url repo tree commit other attempt parent=()
  url="$(forgejo_repo_url "$2" "$3")"
  if $DRY_RUN; then dry "push $dir as the content of $2/$3 main ($(find "$dir" -type f | wc -l) files)"; return; fi
  repo="$WORK/git/$3"
  for attempt in 1 2 3; do
    rm -rf "$repo"; git init -q "$repo"; parent=()
    if forgejo_git -C "$repo" fetch -q "$url" "+refs/heads/main:refs/remotes/origin/main" 2>/dev/null; then
      parent=(-p refs/remotes/origin/main)
      other="$(git -C "$repo" log --format=%s refs/remotes/origin/main \
        | awk '/^okdp-sandbox / {exit} $0 != "okdp: compile" {print; exit}')"
      [[ -z "$other" || "${5:-}" == --force ]] \
        || die "$2/$3 main has commits made elsewhere since the last push (\"$other\": the console?): bring them into this repository first, or --force to replace them"
    fi
    GIT_INDEX_FILE="$repo/.git/okdp.index" git -C "$dir" --git-dir="$repo/.git" --work-tree="$dir" add -A
    tree="$(GIT_INDEX_FILE="$repo/.git/okdp.index" git --git-dir="$repo/.git" write-tree)"
    if [[ ${#parent[@]} -gt 0 && "$(git -C "$repo" rev-parse 'refs/remotes/origin/main^{tree}')" == "$tree" ]]; then
      echo "$2/$3: up to date"
      return
    fi
    commit="$(forgejo_git -C "$repo" commit-tree "$tree" "${parent[@]}" -m "$4")"
    if forgejo_git -C "$repo" push -q "$url" "$commit:refs/heads/main"; then
      echo "pushed $2/$3 main (${commit:0:12})"
      return
    fi
    echo "$2/$3: main moved during the push (the CI?), pushing again on top of it" >&2
    sleep 2
  done
  die "cannot push $2/$3 main: it keeps moving"
}

# forgejo_ci_workflow DIR: the CI of the sources in the repository whose content is DIR
# (okdp-gitops workflow: okdp-gitops compile on each push, run by 30-forgejo-runner).
# The output is at the root of its repository: in mono, the push of the compile itself
# starts no run.
forgejo_ci_workflow() {
  mkdir -p "$1/.forgejo/workflows"
  "${OKDP_GITOPS:-okdp-gitops}" workflow --branch main >"$1/.forgejo/workflows/okdp-gitops.yaml"
}

# forgejo_push_catalogs: copies each catalog of platform/catalog.yaml that lives on
# this Forgejo (its url) from its source (catalog_origin: a checkout, pushed at the
# catalog's ref, or a Git URL), at the same ref; forced, the copy follows its source.
# A catalog elsewhere is left alone (the server reads it from its url).
forgejo_push_catalogs() {
  local name url ref kind src base path owner repo commit target clone
  base="$(forgejo_cluster_url)"
  while IFS=$'\t' read -r name url ref; do
    if [[ "$url" != "$base/"* ]]; then
      echo "catalog $name: $url is not on this Forgejo, not copied"
      continue
    fi
    path="${url#"$base"/}"; path="${path%.git}"; owner="${path%%/*}"; repo="${path#*/}"
    read -r kind src <<<"$(catalog_origin "$name")"
    forgejo_ensure_org "$owner"
    forgejo_ensure_repo "$owner" "$repo" "OKDP service catalog $name, copied from $src"
    if [[ "$kind" == url ]]; then
      clone="$WORK/catalog-sources/$name"
      if $DRY_RUN; then dry "clone $ref of $src, push it to $owner/$repo"; continue; fi
      rm -rf "$clone"
      git clone -q --bare --single-branch --branch "$ref" "$src" "$clone" \
        || die "catalog $name: cannot clone $ref of $src (--catalog $name=DIR|URL)"
      src="$clone"
    fi
    git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "catalog $name: $src is not a Git repository, cannot push it"
    commit="$(catalog_commit "$src" "$ref")" || die "catalog $name: no $ref in $src"
    target="refs/heads/$ref"
    if git -C "$src" show-ref -q --verify "refs/tags/$ref"; then target="refs/tags/$ref"; fi
    forgejo_push_ref "$src" "$commit" "$target" "$owner" "$repo" --force
  done < <(catalog_list)
}

# forgejo_register_runner OWNER: the CI runner of the sources (30-forgejo-runner),
# registered in Forgejo for the organization OWNER with the label okdp-gitops: the
# offline registration of forgejo-cli, in the Forgejo pod, with the secret of Secret
# okdp-forgejo-runner (10-local-secrets-provider) the runner connects with. Registering
# it again changes nothing.
forgejo_register_runner() {
  local secret
  secret="$(yq '.secrets[] | select(.name == "okdp-forgejo-runner") | .data.secret' "$SECRETS_VALUES")"
  [[ "$secret" =~ ^[0-9a-f]{40}$ ]] \
    || die "${SECRETS_VALUES#"$ROOT"/}: Secret okdp-forgejo-runner, key secret: 40 hexadecimal characters"
  if $DRY_RUN; then dry "runner okdp-gitops of $1 (label okdp-gitops): registered in Forgejo"; return; fi
  kubectl -n "$FORGEJO_NAMESPACE" exec "deploy/$FORGEJO_DEPLOYMENT" -c forgejo -- \
    forgejo forgejo-cli actions register --name okdp-gitops --scope "$1" --labels okdp-gitops \
    --secret "$secret" >/dev/null \
    || die "cannot register the CI runner in Forgejo (forgejo forgejo-cli actions register)"
  echo "runner okdp-gitops of $1: registered"
}

# forgejo_token_secret NAMESPACE SECRET: a new access token of the admin for the
# control plane server (it creates the project repositories of the split topology),
# in Secret NAMESPACE/SECRET, key token (the namespace created if missing). The
# previous token of that name is deleted.
forgejo_token_secret() {
  local name=okdp-control-plane-server token
  if $DRY_RUN; then
    dry "access token $name of $FORGEJO_USER (write:organization, write:repository, read:user), replacing the previous one"
    dry "Secret $1/$2 (key token), namespace $1 created if missing"
    return
  fi
  forgejo_api DELETE "/users/$FORGEJO_USER/tokens/$name"
  [[ "$FORGEJO_STATUS" == 204 || "$FORGEJO_STATUS" == 404 ]] || forgejo_fail "cannot delete the token $name"
  forgejo_api POST "/users/$FORGEJO_USER/tokens" "$(jq -cn --arg n "$name" \
    '{name: $n, scopes: ["write:organization", "write:repository", "read:user"]}')"
  [[ "$FORGEJO_STATUS" == 201 ]] || forgejo_fail "cannot create the token $name"
  token="$(jq -r '.sha1' "$FORGEJO_BODY")"
  rm -f "$FORGEJO_BODY"
  kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $2
  namespace: $1
  labels:
    app.kubernetes.io/managed-by: okdp-sandbox-configure
type: Opaque
stringData:
  token: "$token"
EOF
  echo "Secret $1/$2: the access token $name of $FORGEJO_USER"
}
