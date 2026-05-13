#!/usr/bin/env sh
set -eu

OCI_REPO="oci://quay.io/okdp/charts"
PACKAGE_DIR="./.helm-packages"

mkdir -p "$PACKAGE_DIR"

charts="
cert-issuers
cnpg-postgresql
coredns-patch
dns-server
local-secrets-provider
polaris-admin
seaweedfs-auth-config
spark-defaults
spark-rbac
"

echo "Packaging charts into: $PACKAGE_DIR"
echo "Pushing charts to: $OCI_REPO"
echo

for chart in $charts; do
  if [ ! -d "$chart" ]; then
    echo "Skipping $chart: directory not found"
    continue
  fi

  if [ ! -f "$chart/Chart.yaml" ]; then
    echo "Skipping $chart: Chart.yaml not found"
    continue
  fi

  echo "Updating dependencies for $chart"
  helm dependency update "$chart" || true

  echo "Packaging $chart"
  package_output="$(helm package "$chart" --destination "$PACKAGE_DIR")"

  package_file="$(printf '%s\n' "$package_output" | sed -n 's/^Successfully packaged chart and saved it to: //p')"

  if [ -z "$package_file" ]; then
    echo "Could not detect packaged file for $chart"
    exit 1
  fi

  echo "Pushing $package_file"
  helm push "$package_file" "$OCI_REPO"

  echo "Done: $chart"
  echo
done

echo "All charts packaged and pushed."
