# polaris-admin

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.3.0-incubating](https://img.shields.io/badge/AppVersion-1.3.0--incubating-informational?style=flat-square)

Bootstrap Apache Polaris realms and provision principals and principal roles
using Helm hook Jobs before and after Polaris startup.

**Homepage:** <https://okdp.io/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| idirze | <idir.izitounene@kubotal.io> | <https://github.com/idirze> |

## Source Code

* <https://github.com/OKDP/okdp-sandbox>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| bootstrap | object | `{"annotations":{"helm.sh/hook":"pre-install,pre-upgrade","helm.sh/hook-delete-policy":"before-hook-creation"},"backoffLimit":1,"database":{"jdbcUrl":"","secret":{"name":null,"passwordKey":"password","usernameKey":"username"}},"image":{"pullPolicy":"IfNotPresent","repository":"apache/polaris-admin-tool","tag":"1.3.0-incubating"},"purge":false,"restartPolicy":"Never","ttlSecondsAfterFinished":3600}` | Bootstrap Job configuration. |
| bootstrap.annotations | object | `{"helm.sh/hook":"pre-install,pre-upgrade","helm.sh/hook-delete-policy":"before-hook-creation"}` | Extra annotations to add to the bootstrap Job. |
| bootstrap.annotations."helm.sh/hook" | string | `"pre-install,pre-upgrade"` | Helm hook events to run bootstrap on (example: post-install,post-upgrade). |
| bootstrap.annotations."helm.sh/hook-delete-policy" | string | `"before-hook-creation"` | Helm hook delete policy. |
| bootstrap.backoffLimit | int | `1` | Job backoff limit (number of retries before considering the Job failed). |
| bootstrap.database | object | `{"jdbcUrl":"","secret":{"name":null,"passwordKey":"password","usernameKey":"username"}}` | Polaris metastore database connection settings. |
| bootstrap.database.jdbcUrl | string | `""` | JDBC URL for Polaris metastore database. If set, this value is used directly and `database.secret` is ignored for JDBC URL. |
| bootstrap.database.secret | object | `{"name":null,"passwordKey":"password","usernameKey":"username"}` | Secret-backed database credential settings. |
| bootstrap.database.secret.name | string | `nil` | Secret name containing the database credentials. Required when `database.jdbcUrl` is empty. |
| bootstrap.database.secret.passwordKey | string | `"password"` | Secret key holding the database password. |
| bootstrap.database.secret.usernameKey | string | `"username"` | Secret key holding the database username. |
| bootstrap.image | object | `{"pullPolicy":"IfNotPresent","repository":"apache/polaris-admin-tool","tag":"1.3.0-incubating"}` | Bootstrap container image settings. |
| bootstrap.image.pullPolicy | string | `"IfNotPresent"` | Bootstrap container image pull policy. |
| bootstrap.image.repository | string | `"apache/polaris-admin-tool"` | Bootstrap container image repository. |
| bootstrap.image.tag | string | `"1.3.0-incubating"` | Bootstrap container image tag. |
| bootstrap.purge | bool | `false` | Purge realms and all associated entities. |
| bootstrap.restartPolicy | string | `"Never"` | Job pod restart policy. For Jobs, must be OnFailure or Never. |
| bootstrap.ttlSecondsAfterFinished | int | `3600` | TTL (seconds) for finished Jobs. If empty, Job cleanup is disabled. |
| extraEnv | list | `[]` | Extra env vars to add to the Job container (raw K8s env spec). Example: extraEnv:   - name: HTTPS_PROXY     value: http://proxy:3128 |
| extraVolumeMounts | list | `[]` | Extra volume mounts to attach to the Job container (raw K8s volumeMount spec). Example: extraVolumeMounts:   - name: cacerts     mountPath: /cacerts     readOnly: true |
| extraVolumes | list | `[]` | Extra volumes to attach to the Job pod (raw K8s volume spec). Example: extraVolumes:   - name: cacerts     secret:       secretName: certs-bundle |
| fullnameOverride | string | `""` | Override the full name of the release. |
| nameOverride | string | `""` | Override the name of the chart. |
| phase | string | `"bootstrap"` | Select which job this release should render. Valid values:   - bootstrap   - principals |
| principals | object | `{"annotations":{"helm.sh/hook":"post-install,post-upgrade","helm.sh/hook-delete-policy":"before-hook-creation"},"backoffLimit":1,"caCertPath":"/cacerts/ca.crt","image":{"pullPolicy":"IfNotPresent","repository":"curlimages/curl","tag":"8.18.0"},"insecureSkipVerify":true,"polaris":{"url":""},"restartPolicy":"Never","ttlSecondsAfterFinished":3600,"waitIntervalSeconds":3,"waitTimeoutSeconds":300}` | Principal provisioning Job configuration. |
| principals.annotations | object | `{"helm.sh/hook":"post-install,post-upgrade","helm.sh/hook-delete-policy":"before-hook-creation"}` | Extra annotations to add to the principal provisioning Job. |
| principals.annotations."helm.sh/hook" | string | `"post-install,post-upgrade"` | Helm hook events to run provisioning on. |
| principals.annotations."helm.sh/hook-delete-policy" | string | `"before-hook-creation"` | Helm hook delete policy. |
| principals.backoffLimit | int | `1` | Job backoff limit. |
| principals.caCertPath | string | `"/cacerts/ca.crt"` | Path to a PEM CA bundle inside the Job container (used by curl for TLS validation). You said you already have it mounted at /cacerts/ca.crt. |
| principals.image | object | `{"pullPolicy":"IfNotPresent","repository":"curlimages/curl","tag":"8.18.0"}` | Principal provisioning container image settings. |
| principals.image.pullPolicy | string | `"IfNotPresent"` | Job container image pull policy. |
| principals.image.repository | string | `"curlimages/curl"` | Job container image repository (must include /bin/sh and curl). |
| principals.image.tag | string | `"8.18.0"` | Job container image tag. |
| principals.insecureSkipVerify | bool | `true` | Skip TLS verification when calling Polaris (useful with self-signed certs). |
| principals.polaris | object | `{"url":""}` | Polaris API endpoint settings. |
| principals.polaris.url | string | `""` | Base URL of the Polaris service (e.g. https://polaris-default.okdp.sandbox). Used by the Job to call Polaris management APIs. |
| principals.restartPolicy | string | `"Never"` | Job pod restart policy. For Jobs, must be OnFailure or Never. |
| principals.ttlSecondsAfterFinished | int | `3600` | TTL (seconds) for finished Jobs. If empty, Job cleanup is disabled. |
| principals.waitIntervalSeconds | int | `3` | Seconds between readiness checks. |
| principals.waitTimeoutSeconds | int | `300` | Max seconds to wait for Polaris readiness. |
| realms | list | `[]` | List of allowed Polaris realms used by the default realm context resolver. The first realm in this list is treated as the default realm. Any realm not listed here will be rejected.  Each realm entry also defines the bootstrap (root) client credentials used to obtain a management token and provision admin principals. The root bootstrap principal should be treated as bootstrap/break-glass only (not for normal day-to-day OIDC flows).  If this list is empty OR no realm contains principals entries, the Job will not be rendered. principal -> principal role -> catalog role -> privilege https://polaris.apache.org/in-dev/unreleased/managing-security/access-control |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.13.1](https://github.com/norwoodj/helm-docs/releases/v1.13.1)
