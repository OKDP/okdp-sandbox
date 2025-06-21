# Installing OKDP Sandbox Certificate

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
