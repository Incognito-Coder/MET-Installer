#!/bin/bash
set -euo pipefail

echo "=== Stopping services ==="
systemctl stop matrix-synapse coturn nginx || true
systemctl disable matrix-synapse coturn nginx || true

echo "=== Removing UFW rules ==="
if command -v ufw &> /dev/null; then
  ufw delete allow 22 || true
  ufw delete allow 80 || true
  ufw delete allow 443 || true
  ufw delete allow 3478 || true
  ufw delete allow 5349 || true
  ufw delete allow 49152:65535/udp || true
fi

echo "=== Removing SSL certs ==="
CERT_NAME=$(grep -oP '(?<=d=)[^ ]+' /etc/letsencrypt/renewal/*.conf | head -n 1 || true)
if [ -n "$CERT_NAME" ]; then
  certbot delete --non-interactive --cert-name "$CERT_NAME"
else
  echo "No certbot certificates found to remove."
fi

echo "=== Removing Nginx configurations ==="
rm -f /etc/nginx/sites-available/matrix
rm -f /etc/nginx/sites-available/element
rm -f /etc/nginx/sites-enabled/matrix
rm -f /etc/nginx/sites-enabled/element

echo "=== Purging packages ==="
apt purge -y matrix-synapse-py3 element-web coturn nginx certbot python3-certbot-nginx postgresql postgresql-contrib
apt autoremove -y

echo "=== Removing repositories ==="
rm -f /etc/apt/sources.list.d/matrix-org.list
rm -f /usr/share/keyrings/matrix-org.gpg
rm -f /etc/apt/sources.list.d/element-io.list
rm -f /usr/share/keyrings/element-io-archive-keyring.gpg
apt update

echo "=== Dropping Synapse database and user ==="
sudo -u postgres psql -c "DROP DATABASE IF EXISTS synapse_db;"
sudo -u postgres psql -c "DROP USER IF EXISTS synapse_user;"

echo "===================================="
echo "✅ UNINSTALL COMPLETE"
echo "===================================="
