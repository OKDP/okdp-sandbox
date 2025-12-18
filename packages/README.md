# OKDP Packages

## Structure

```
packages/
├── system/             # Infrastructure & system packages
│   ├── cert-manager/
│   ├── ingress-nginx/
│   ├── dns-server/
│   └── ...
└── okdp-packages/      # OKDP packages
    ├── superset/
    ├── jupyterhub/
    ├── minio/
    └── ...
```

## Building Packages

### Basic Build Command

```bash
# Build a system package
kubocd pack --ociRepoPrefix quay.io/okdp/sandbox-packages-v0.1 ./packages/system/cert-manager/cert-manager.yaml

# Build an OKDP package
kubocd pack --ociRepoPrefix quay.io/okdp/sandbox-packages-v0.1 ./packages/okdp-packages/superset/superset.yaml
```

### Custom OCI Repository

```bash
# Using a different OCI registry
kubocd pack --ociRepoPrefix myregistry.io/my-org/packages-v0.1 ./packages/system/cert-manager/cert-manager.yaml

# Using a different prefix for packages
kubocd pack --ociRepoPrefix harbor.company.com/okdp-prod ./packages/okdp-packages/jupyterhub/jupyterhub.yaml
```

### Examples

```bash
# Build all system packages
for pkg in packages/system/*/; do
  kubocd pack --ociRepoPrefix quay.io/okdp/sandbox-packages-v0.1 "$pkg"*.yaml
done

# Build specific package
kubocd pack --ociRepoPrefix quay.io/okdp/sandbox-packages-v0.1 ./packages/okdp-packages/minio/minio.yaml
```

### Build Output

Packages are pushed to: `{ociRepoPrefix}/{package-name}:{tag}`

Example: `quay.io/okdp/sandbox-packages-v0.1/superset:4.0.0-p02` 