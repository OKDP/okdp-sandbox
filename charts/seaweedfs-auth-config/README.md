# seaweedfs-auth-config

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

SeaweedFS Auth and IAM/STS configuration

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
| annotations | object | `{}` | Extra annotations to add to the ConfigMap metadata. |
| filer | object | `{"auth":{"basic":{"create_auth_secret":"creds-seaweedfs-filer-basic","password":"admin123","username":"admin"},"method":"basic"}}` | SeaweedFS filer configuration. |
| filer.auth | object | `{"basic":{"create_auth_secret":"creds-seaweedfs-filer-basic","password":"admin123","username":"admin"},"method":"basic"}` | Authentication settings for the filer endpoint. |
| filer.auth.basic.create_auth_secret | string | `"creds-seaweedfs-filer-basic"` | Name of the Kubernetes Secret to create/use for NGINX basic auth (htpasswd file) based on username and password. This Secret is referenced by the ingress annotation: nginx.ingress.kubernetes.io/auth-secret: <secret-name> |
| filer.auth.basic.password | string | `"admin123"` | Basic auth password used to generate the htpasswd entry. Consider supplying via an existing Secret or external secret manager in real deployments. |
| filer.auth.basic.username | string | `"admin"` | Basic auth username used to generate the htpasswd entry. |
| filer.auth.method | string | `"basic"` | Authentication method for filer access. Supported values: "basic" (extend if you add other methods later). |
| fullnameOverride | string | `""` | Override the full release name (affects resource naming). |
| iamConfig | object | `{"policies":[],"providers":{"oidc":{"clientId":"","configExtra":{},"enabled":false,"issuer":"","jwksUri":"","providerName":"oidc-provider","providerType":"oidc","roleMapping":{"defaultRole":"","rules":[]},"scope":"","scopes":[],"userInfoUri":""}},"roles":[],"sts":{"issuer":"seaweedfs-sts","maxSessionLength":"12h","signingKey":"","tokenDuration":"1h"}}` | SeaweedFS IAM and STS configuration rendered into iam.json. |
| iamConfig.policies | list | `[]` | IAM policies to define in the SeaweedFS IAM config. Example: policies:   - name: "S3WritePolicy"     document:       Version: "2012-10-17"       Statement:         - Effect: "Allow"           Action: ["s3:List*","s3:Get*","s3:Put*","s3:DeleteObject"]           Resource: ["*"] |
| iamConfig.providers | object | `{"oidc":{"clientId":"","configExtra":{},"enabled":false,"issuer":"","jwksUri":"","providerName":"oidc-provider","providerType":"oidc","roleMapping":{"defaultRole":"","rules":[]},"scope":"","scopes":[],"userInfoUri":""}}` | Identity provider configuration for SeaweedFS IAM. |
| iamConfig.providers.oidc | object | `{"clientId":"","configExtra":{},"enabled":false,"issuer":"","jwksUri":"","providerName":"oidc-provider","providerType":"oidc","roleMapping":{"defaultRole":"","rules":[]},"scope":"","scopes":[],"userInfoUri":""}` | OIDC provider configuration for SeaweedFS IAM. |
| iamConfig.providers.oidc.clientId | string | `""` | OIDC client id. Example: "seaweedfs-s3" |
| iamConfig.providers.oidc.configExtra | object | `{}` | Extra provider-specific config fields to merge into the provider "config" object. Use this to add any non-standard keys your provider or SeaweedFS config requires. Example: configExtra:   audience: "my-audience"   tokenEndpoint: "https://issuer.example.com/oauth/token" |
| iamConfig.providers.oidc.enabled | bool | `false` | Enable/disable OIDC provider configuration rendering. |
| iamConfig.providers.oidc.issuer | string | `""` | OIDC Issuer URL. Example: "https://keycloak.example.com/realms/master" |
| iamConfig.providers.oidc.jwksUri | string | `""` | JWKS URI (do NOT assume Keycloak paths; set explicitly per provider). Example (Keycloak): "https://keycloak.example.com/realms/master/protocol/openid-connect/certs" Example (Auth0):   "https://YOUR_DOMAIN/.well-known/jwks.json" |
| iamConfig.providers.oidc.providerName | string | `"oidc-provider"` | Provider display/name identifier inside the generated IAM config. |
| iamConfig.providers.oidc.providerType | string | `"oidc"` | Provider type field to emit (SeaweedFS expects "oidc" for OIDC providers). |
| iamConfig.providers.oidc.roleMapping | object | `{"defaultRole":"","rules":[]}` | Claim-to-role mapping for AssumeRoleWithWebIdentity. |
| iamConfig.providers.oidc.roleMapping.defaultRole | string | `""` | Default role ARN if no rule matches. Must be a valid IAM Role ARN. Format: arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> Example: "arn:aws:iam::000000000000:role/S3ReadOnlyRole" N.B.: roleMapping is only relevant for sts:AssumeRoleWithWebIdentity |
| iamConfig.providers.oidc.roleMapping.rules | list | `[]` | List of rule mappings to derive a role from token claims. Each rule matches a claim/value and maps to a role ARN. Example: rules:   - claim: "groups"     value: "developers"     role: "arn:aws:iam::000000000000:role/S3WriteRole" |
| iamConfig.providers.oidc.scope | string | `""` | OIDC scopes input as a single string. The chart will normalize this to `scopes: []` in the generated iam.json. Notes: - OAuth/OIDC "scope" is typically SPACE-separated (standard). - Some people write "+" (often URL-encoding for spaces) or commas. The chart accepts space, "+", or comma. Examples:   scope: "openid profile email offline_access groups"   scope: "openid+profile+email+offline_access+groups"   scope: "openid,profile,email,offline_access,groups" |
| iamConfig.providers.oidc.scopes | list | `[]` | OIDC scopes input as an explicit list. If set (non-empty), it takes precedence over `scope`. Example:   scopes: ["openid","profile","email","offline_access","groups"] |
| iamConfig.providers.oidc.userInfoUri | string | `""` | UserInfo endpoint URI (optional; not all providers expose it). Example (Keycloak): "https://keycloak.example.com/realms/master/protocol/openid-connect/userinfo" |
| iamConfig.roles | list | `[]` | IAM roles to define in the SeaweedFS IAM config. Example: roles:   - roleName: "S3WriteRole"     roleArn: "arn:aws:iam::000000000000:role/S3WriteRole"     attachedPolicies: ["S3WritePolicy"]     trustPolicy:       Version: "2012-10-17"       Statement:         - Effect: "Allow"           Principal: "*"           Action:             - "sts:AssumeRole"         - Effect: "Allow"           Principal: { Federated: "*" }           Action:             - "sts:AssumeRoleWithWebIdentity"           Condition:             StringEquals:               seaweed:Issuer: "https://issuer.example.com/realms/master" |
| iamConfig.sts | object | `{"issuer":"seaweedfs-sts","maxSessionLength":"12h","signingKey":"","tokenDuration":"1h"}` | SeaweedFS STS configuration rendered into iam.json. |
| iamConfig.sts.issuer | string | `"seaweedfs-sts"` | Logical issuer name used by SeaweedFS STS tokens (not the OIDC issuer URL). |
| iamConfig.sts.maxSessionLength | string | `"12h"` | Maximum allowed session length for STS tokens (e.g. "12h"). |
| iamConfig.sts.signingKey | string | `""` | Base64-encoded signing key used by SeaweedFS to sign STS tokens. Example: "b64:Zm9vYmFy..." (recommend supplying via a Secret in real deployments) |
| iamConfig.sts.tokenDuration | string | `"1h"` | Default duration for vended STS tokens (e.g. "1h", "30m"). |
| nameOverride | string | `""` | Override the chart name (affects resource naming). |
| s3Config | object | `{"annotations":{"helm.sh/hook":"pre-install,pre-upgrade","helm.sh/resource-policy":"keep"},"enabled":false,"identities":[],"secretName":""}` | SeaweedFS S3 auth config secret (existingConfigSecret) |
| s3Config.annotations | object | `{"helm.sh/hook":"pre-install,pre-upgrade","helm.sh/resource-policy":"keep"}` | Extra annotations to add to the generated S3 config Secret. |
| s3Config.annotations."helm.sh/hook" | string | `"pre-install,pre-upgrade"` | Helm hook events for the generated S3 config Secret. |
| s3Config.annotations."helm.sh/resource-policy" | string | `"keep"` | Helm resource policy for the generated S3 config Secret. |
| s3Config.enabled | bool | `false` | Create the SeaweedFS S3 config secret from `identities` |
| s3Config.identities | list | `[]` | S3 identities rendered into a SeaweedFS-compatible secret (existingConfigSecret) Example: identities:   - name: polaris     credentialsSecret:       name: creds-polaris-s3       accessKeyKey: accessKey       secretKeyKey: secretKey     actions: ["Admin","Read","Write","List","Tagging"] |
| s3Config.secretName | string | `""` | Name of the secret you will reference from SeaweedFS values: s3:   enableAuth: true   existingConfigSecret: MyExistingSecret |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.13.1](https://github.com/norwoodj/helm-docs/releases/v1.13.1)
