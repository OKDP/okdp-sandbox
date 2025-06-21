# DNS Configuration Guide

This guide provides detailed instructions for configuring local DNS resolution for the OKDP sandbox environment.

## Option 1: Manual /etc/hosts Configuration

Add the following entries to your `/etc/hosts` file for each service that will be deployed:
```
127.0.0.1 keycloak.okdp.sandbox kad.okdp.sandbox okdp-server.okdp.sandbox okdp-ui.okdp.sandbox 
```

**Important**: Always use a single line for all hostnames pointing to 127.0.0.1. Having multiple lines with the same IP address (127.0.0.1) can cause DNS resolution problems.

**Note**: You will need to manually add DNS entries for each additional service deployed through the frontend.

## Option 2: Local DNS Server Configuration (Recommended)

The sandbox deploys a DNS server exposed on port 30053. Configure your local resolver to point to `localhost:30053` for the `okdp.sandbox` domain.

### macOS Configuration

```bash
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/okdp.sandbox
echo "port 30053" | sudo tee -a /etc/resolver/okdp.sandbox
```

### Linux with systemd-resolved

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
cat > /tmp/okdp-sandbox.conf <<EOF
[Resolve]
DNS=127.0.0.1:30053
Domains=~okdp.sandbox
EOF
sudo mv /tmp/okdp-sandbox.conf /etc/systemd/resolved.conf.d/
sudo systemctl restart systemd-resolved
```

### Linux with NetworkManager

```bash
nmcli connection modify "$(nmcli -t -f NAME connection show --active | head -n1)" ipv4.dns-search "okdp.sandbox" ipv4.dns "127.0.0.1:30053"
sudo systemctl restart NetworkManager
```

### Linux with dnsmasq

```bash
echo "server=/okdp.sandbox/127.0.0.1#30053" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq
```

### Windows

1. Open PowerShell as Administrator
2. Run the following commands:
```powershell
# Add DNS server for the domain
netsh interface ip set dns "Local Area Connection" static 127.0.0.1
# Note: You may need to adjust "Local Area Connection" to match your network interface name
```

## Verification

To verify that DNS resolution is working correctly:

```bash
# Test with dig
dig @127.0.0.1 -p 30053 okdp-ui.okdp.sandbox

# Test DNS resolution (Linux/Windows)
nslookup okdp-ui.okdp.sandbox
# Should resolve to 127.0.0.1

```

## Troubleshooting

### DNS Server Not Responding
- Ensure the Kind cluster is running: `kind get clusters`
- Check that port 30053 is properly mapped: `docker ps | grep okdp-sandbox`
- Verify the DNS service is running in the cluster: `kubectl get svc -A | grep dns`

### DNS Resolution Still Not Working
- Clear DNS cache:
  - **macOS**: `sudo dscacheutil -flushcache`
  - **Linux**: `sudo systemctl restart systemd-resolved` or `sudo service nscd restart`
  - **Windows**: `ipconfig /flushdns`

### Reverting Changes
- **macOS**: `sudo rm /etc/resolver/okdp.sandbox`
- **Linux (systemd-resolved)**: `sudo rm /etc/systemd/resolved.conf.d/okdp-sandbox.conf && sudo systemctl restart systemd-resolved`
- **Linux (NetworkManager)**: Reset network configuration through NetworkManager