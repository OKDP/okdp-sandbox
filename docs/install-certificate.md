# Installing OKDP Sandbox Certificate

> The sandbox CA ("OKDP Sandbox Self-Signed CA") can sign a certificate for any name,
> and its key lives in the sandbox cluster. Prefer a browser profile dedicated to the
> sandbox over the system store, and remove the certificate once you are done
> ([Removing the certificate](#removing-the-certificate)).

## System Installation

### macOS
1. Double-click `okdp-sandbox-ca.crt`
2. Choose "Keychain Access" → "System" keychain
3. Find "OKDP Sandbox Self-Signed CA" → Right-click → "Get Info"
4. Expand "Trust" → Set "Secure Sockets Layer (SSL)" to "Always Trust"

### Linux (Ubuntu/Debian)
```bash
sudo cp okdp-sandbox-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Windows
1. Right-click `okdp-sandbox-ca.crt` → "Install Certificate"
2. Choose "Local Machine" → "Place all certificates in the following store"
3. Browse → "Trusted Root Certification Authorities" → OK

## Browser Installation

### Chrome
1. Settings → Privacy and security → Security → Manage certificates
2. **macOS/Linux**: Authorities tab → Import → Select `okdp-sandbox-ca.crt`
3. **Windows**: Trusted Root Certification Authorities → Import

### Firefox  
1. Settings → Privacy & Security → Certificates → View Certificates
2. Authorities tab → Import → Select `okdp-sandbox-ca.crt`
3. Check "Trust this CA to identify websites"

### Safari
Uses the macOS system keychain (see macOS system installation above).

## Removing the certificate

Undo the installation above once the sandbox is deleted.

### macOS
```bash
sudo security delete-certificate -c "OKDP Sandbox Self-Signed CA" /Library/Keychains/System.keychain
```
(or Keychain Access → "System" keychain → "OKDP Sandbox Self-Signed CA" → Delete)

### Linux (Ubuntu/Debian)
```bash
sudo rm /usr/local/share/ca-certificates/okdp-sandbox-ca.crt
sudo update-ca-certificates --fresh
```

### Windows
In PowerShell as Administrator:
```powershell
Get-ChildItem Cert:\LocalMachine\Root |
  Where-Object Subject -like "*OKDP Sandbox Self-Signed CA*" | Remove-Item
```
(or `certlm.msc` → Trusted Root Certification Authorities → Certificates → delete it)

### Chrome / Firefox
Same place as the import (Manage certificates / View Certificates → Authorities), select
"OKDP Sandbox Self-Signed CA" (organization "OKDP") → Delete.
