# TrinoDB Access Guide

This document provides instructions on how to authenticate and interact with the TrinoDB service using the Command Line Interface (CLI) and the HTTP API.

## Authentication with Authorization Flow for Human User

Trino is configured with OAuth2 authentication. Before performing any operations, you must obtain a valid access token.

### Retrieving the Access Token

1. **Log in** to the Trino web interface.
2. **Retrieve the token** from your browser cookies:
   - Open Developer Tools.
   - Look for the cookie named `__Secure-Trino-Oauth2-Token`.
   - Copy the token value.

3. **Export the token** as an environment variable for use in commands:

   ```bash
   export TOKEN="<PASTE_YOUR_OAUTH2_TOKEN_HERE>"
   ```

   > **Note**: The token is a long JWT string. Ensure you copy the entire value.

## Connection Methods

### 1. Trino CLI

You can use the native `trino` CLI to run interactive queries. The following command connects to the Trino server securely using the exported token.

**Command:**

```bash
trino \
  --server=https://localhost:8443 \
  --user=usera \
  --access-token=$TOKEN \
  --insecure
```

**Parameters:**
- `--server`: The URL of the Trino coordinator. Use `localhost` if properly forwarded or running locally.
- `--user`: The username to identify as (e.g., `usera`).
- `--access-token`: The OAuth2 bearer token.
- `--insecure`: Skips SSL certificate validation (useful for self-signed certificates in sandbox environments).

---

### 2. HTTP API (cURL)

You can interact with Trino programmatically using `cURL`. This is useful for testing connectivity or automating queries.

**Example: Show Catalogs**

```bash
curl -sk \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Trino-User: usera" \
  --data-binary 'SHOW CATALOGS' \
  https://trinodb-<TRINO_SUFFIX>.okdp.sandbox/v1/statement
```

**Header Details:**
- `X-Trino-User`: Specifies the effective user for the transaction.
- `Authorization`: Passes the Bearer token for authentication.

## Authentication with Client Credentials Flow for Service Account

### Keycloak Side Configuration

You must create a specific "Client" for your application or automated script.

- **Client ID**: `trino-m2m-app` (for example).
- **Access Type**: `confidential`.
- **Service Accounts Enabled**: `ON` (This is the crucial option for M2M).
- **Standard Flow Enabled**: `OFF` (No need for browser redirection).
- **Mappers**: If needed, ensure you add a "Protocol Mapper" to include a `preferred_username` or `sub` field in the token, as Trino uses it to identify the user executing the query.

> In the **Service Account Roles** tab of the client, you can assign specific roles to this application to manage its permissions in Trino via RBAC.

### Verification Example

To test the applicative user (M2M), follow these steps:

1. **Obtain the Access Token**:

   ```bash
   export SECRET="<YOUR_CLIENT_SECRET>"
   export CLIENT_ID="trino-m2m-app"
   
   # Adjust the Keycloak URL if needed
   curl -ks -X POST "https://keycloak.okdp.sandbox/realms/master/protocol/openid-connect/token" \
    -d "grant_type=client_credentials" \
    -d "scope=openid" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${SECRET}" | jq
   ```

2. **Export the Token**:

   ```bash
   export TOKEN="<ACCESS_TOKEN_FROM_RESPONSE>"

3. **Test with cURL**:

   ```bash
   # Adjust the Trino URL if needed
   curl -skL -X POST https://trino-<TRINO_SUFFIX>.okdp.sandbox/v1/statement \
     -H "Authorization: Bearer $TOKEN" \
     --data 'SHOW CATALOGS' | jq
   ```

4. **Test with Trino CLI**:

   ```bash
   # Ensure you have port-forwarded Trino to localhost:8443
   trino \
     --server=https://localhost:8443 \
     --user=service-account-${CLIENT_ID} \
     --access-token=$TOKEN \
     --insecure
   ```
