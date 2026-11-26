#!/bin/sh
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
# Exports the OKDP manifests of project-demo (Namespace, Connections and
# service Releases) as individual files under <target-dir>/projects/demo/.
# Usage: ./clusters/sandbox/project-demo/import-gitops.sh [target-dir]

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
TARGET_DIR=${1:-"$REPO_ROOT/clusters/sandbox/control-plane"}
case "$TARGET_DIR" in
  -*|/) echo "invalid target directory: $TARGET_DIR" >&2; exit 1 ;;
esac
DEMO_OUT="$TARGET_DIR/projects/demo"

mkdir -p -- "$DEMO_OUT/connections" "$DEMO_OUT/releases"
rm -f -- "$DEMO_OUT/connections/"*.yaml "$DEMO_OUT/releases/"*.yaml
cp -- "$SCRIPT_DIR/00-namespace.yaml" "$DEMO_OUT/namespace.yaml"

split_yaml() {
  src=$1
  dst=$2
  OUT="$dst" awk '
    BEGIN {
      out = ENVIRON["OUT"]
      valid_name = "^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$"
    }
    function flush_doc() {
      if (!has_name) return
      if (name !~ valid_name) {
        print "invalid metadata.name: " name > "/dev/stderr"
        bad = 1
        exit 1
      }
      print buf > (out "/" name ".yaml")
      close(out "/" name ".yaml")
    }
    /^---[[:space:]]*$/ {
      flush_doc()
      buf = ""; name = ""; has_name = 0; in_meta = 0; next
    }
    { buf = (buf == "" ? $0 : buf "\n" $0) }
    /^metadata:[[:space:]]*$/ { in_meta = 1; next }
    in_meta && /^[^[:space:]#]/ { in_meta = 0 }
    in_meta && /^  name:[[:space:]]*/ {
      val = $0
      sub(/^  name:[[:space:]]*/, "", val)
      sub(/[[:space:]]*#.*$/, "", val)
      sub(/[[:space:]]*$/, "", val)
      len = length(val)
      if (len >= 2 && ((substr(val, 1, 1) == "\"" && substr(val, len, 1) == "\"") || (substr(val, 1, 1) == "\047" && substr(val, len, 1) == "\047"))) {
        val = substr(val, 2, len - 2)
      }
      name = val
      has_name = 1
      in_meta = 0
    }
    END {
      if (bad) exit 1
      flush_doc()
    }
  ' "$src"
}

split_yaml "$SCRIPT_DIR/40-connections.yaml" "$DEMO_OUT/connections"
split_yaml "$SCRIPT_DIR/50-services.yaml" "$DEMO_OUT/releases"

echo "Exported project-demo manifests to $DEMO_OUT"
