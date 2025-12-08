# cert-issuers Helm Chart

A Helm chart for managing cert-manager ClusterIssuers and Certificate bundles.

## Features

- 🔐 **CA-based ClusterIssuers**: Create ClusterIssuers using existing CA certificates
- 🔑 **Self-signed ClusterIssuers**: Generate self-signed CA certificates and ClusterIssuers
- 📦 **Trust Bundles**: Create trust-manager bundles for certificate distribution
- 🔄 **Certificate Replication**: Replicate certificates across namespaces
- ✅ **Validation**: Built-in validation for configuration
- 🏷️ **Labels & Annotations**: Comprehensive labeling for resource management

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- cert-manager v1.0+ installed
- trust-manager (optional, for bundle functionality)

## Installation

```bash
helm install cert-issuers ./cert-issuers
```

## Configuration

### CA-based ClusterIssuers

Create ClusterIssuers using existing CA certificates:

```yaml
caClusterIssuers:
  - name: my-ca-issuer
    ca_crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...  # Base64 encoded CA cert
    ca_key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...  # Base64 encoded private key (optional)
```

### Self-signed ClusterIssuers

Generate self-signed CA certificates and ClusterIssuers:

```yaml
selfSignedClusterIssuers:
  - name: self-signed-ca
    certificate:
      commonName: "My Self-Signed CA"
      organization: "My Organization"
      country: "US"
      validity: "8760h"  # 1 year
      algorithm: "ECDSA"
      size: 256
```

### Trust Bundles

Create trust-manager bundles for certificate distribution:

```yaml
bundle:
  enabled: true
  name: "certs-bundle"
  useDefaultCAs: true
  target:
    configMap:
      enabled: true
      key: "root-certs.pem"
    secret:
      enabled: true
      key: "ca.crt"
  namespaceSelector:
    matchLabels:
      cert-bundle: "enabled"
```

### Certificate Replication

Enable certificate replication across namespaces:

```yaml
replication:
  enabled: true
  method: "replicator"  # or "kubed"
  allowedNamespaces: ".*"
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `global.certificateNamespace` | string | `""` | Namespace for certificates (defaults to release namespace) |
| `caClusterIssuers` | list | `[]` | List of CA-based ClusterIssuers |
| `selfSignedClusterIssuers` | list | `[]` | List of self-signed ClusterIssuers |
| `bundle.enabled` | bool | `false` | Enable trust bundle creation |
| `bundle.name` | string | `"certs-bundle"` | Name of the trust bundle |
| `bundle.useDefaultCAs` | bool | `true` | Include system default CAs |
| `replication.enabled` | bool | `true` | Enable certificate replication |
| `replication.method` | string | `"replicator"` | Replication method (replicator/kubed) |

## Examples

### Basic CA Issuer

```yaml
caClusterIssuers:
  - name: company-ca
    ca_crt: LS0tLS1CRUdJTi0tLS0t...
    ca_key: LS0tLS1CRUdJTi0tLS0t...
```

### Self-signed with Custom Config

```yaml
selfSignedClusterIssuers:
  - name: dev-ca
    certificate:
      commonName: "Development CA"
      organization: "Dev Team"
      validity: "2160h"  # 90 days
      algorithm: "RSA"
      size: 2048
```

### Full Configuration

```yaml
caClusterIssuers:
  - name: prod-ca
    ca_crt: LS0tLS1CRUdJTi0tLS0t...

selfSignedClusterIssuers:
  - name: dev-ca

bundle:
  enabled: true
  name: company-certs
  target:
    configMap:
      enabled: true
    secret:
      enabled: true

replication:
  enabled: true
  method: replicator
  allowedNamespaces: "dev-.*|staging-.*"
```

## Security Considerations

⚠️ **Warning**: Storing private keys in Helm values is not recommended for production environments. Consider using:

- External secret management (HashiCorp Vault, AWS Secrets Manager, etc.)
- Kubernetes External Secrets Operator
- Sealed Secrets

## Testing

The chart includes comprehensive tests. Run them with:

```bash
helm unittest ./cert-issuers
```

## Troubleshooting

### Check ClusterIssuers Status

```bash
kubectl get clusterissuers
kubectl describe clusterissuer <issuer-name>
```

### Check Certificate Status

```bash
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>
```

### Check Trust Bundle

```bash
kubectl get bundles
kubectl describe bundle <bundle-name>
```

## Contributing

1. Make changes to the chart
2. Update tests
3. Run `helm lint ./cert-issuers`
4. Run `helm unittest ./cert-issuers`
5. Update documentation

## License

This chart is licensed under the Apache License 2.0. 