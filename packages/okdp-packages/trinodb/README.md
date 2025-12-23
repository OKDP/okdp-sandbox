# TrinoDB Access Guide

This document provides instructions on how to authenticate and interact with the TrinoDB service using the Command Line Interface (CLI) and the HTTP API.

## Authentication

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
  https://trinodb-fn9nhy.okdp.sandbox/v1/statement
```

**Header Details:**
- `X-Trino-User`: Specifies the effective user for the transaction.
- `Authorization`: Passes the Bearer token for authentication.
