#!/bin/bash
set -e

### ===== CONFIG =====
# Usage: ./install.sh [MATRIX_DOMAIN] [ELEMENT_DOMAIN] [TURN_DOMAIN] [EMAIL]
MATRIX_DOMAIN=${1:-"matrix.mrscript.ir"}
ELEMENT_DOMAIN=${2:-"element.mrscript.ir"}
TURN_DOMAIN=${3:-"turn.mrscript.ir"}
EMAIL=${4:-"alireza.ahmand@yahoo.com"}
SERVER_IP="$(curl -s ifconfig.me)"
TURN_SECRET="$(openssl rand -hex 32)"
SYNAPSE_DB_PASSWORD="$(openssl rand -hex 32)"

### ===== BEGIN ======
echo "=== Updating system ==="
apt update && apt upgrade -y

echo "=== Installing base packages ==="
apt install -y curl wget gnupg lsb-release ufw nginx certbot python3-certbot-nginx postgresql coturn

echo "=== Creating Synapse database ==="
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='synapse_user'" | grep -q 1 || sudo -u postgres psql -c "CREATE USER synapse_user WITH PASSWORD '$SYNAPSE_DB_PASSWORD';"
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw synapse_db; then
    sudo -u postgres psql -c "CREATE DATABASE synapse_db WITH OWNER synapse_user TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C';"
fi

### MATRIX REPO
echo "=== Adding Matrix repo ==="
wget -4 -O /usr/share/keyrings/matrix-org.gpg https://packages.matrix.org/debian/matrix-org-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/matrix-org.gpg] https://packages.matrix.org/debian/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/matrix-org.list

apt update && apt install -y matrix-synapse-py3

echo "=== Configuring Synapse for PostgreSQL ==="
sed -i '/^database:/,+3s/^/#/' /etc/matrix-synapse/homeserver.yaml

cat >> /etc/matrix-synapse/homeserver.yaml <<EOF

database:
  name: psycopg2
  args:
    user: synapse_user
    password: "$SYNAPSE_DB_PASSWORD"
    database: synapse_db
    host: localhost
    cp_min: 5
    cp_max: 10

max_upload_size: 200M
max_avatar_size: 20M

experimental_features:
  msc3266_enabled: true   # Matrix RTC

rtc:
  enabled: true
  focus:
    type: livekit
    url: $TURN_DOMAIN

enable_registration: true
enable_registration_without_verification: true

turn_uris:
  - "turn:$TURN_DOMAIN:3478?transport=udp"
  - "turn:$TURN_DOMAIN:3478?transport=tcp"
  - "turns:$TURN_DOMAIN:5349?transport=tcp"

turn_shared_secret: "$TURN_SECRET"
turn_user_lifetime: 1h
turn_allow_guests: true
EOF

systemctl restart matrix-synapse

### ELEMENT WEB
echo "=== Installing Element Web ==="
wget -4 -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" > /etc/apt/sources.list.d/element-io.list
apt update && apt install -y element-web

cat > /usr/share/element-web/config.json <<EOF
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://$MATRIX_DOMAIN",
      "server_name": "$MATRIX_DOMAIN"
    }
  },
  "disable_custom_urls": true
}
EOF

### NGINX
echo "=== Configuring Nginx ==="

cat > /etc/nginx/sites-available/matrix <<EOF
server {
  listen 80;
  server_name $MATRIX_DOMAIN;
  client_max_body_size 5000M;

  location /.well-known/matrix/client {
    return 200 '{"m.homeserver": {"base_url": "https://$MATRIX_DOMAIN"}}';
    add_header Content-Type application/json;
    add_header "Access-Control-Allow-Origin" *;
  }

  location / {
    proxy_pass http://localhost:8008;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
  }
}
EOF

cat > /etc/nginx/sites-available/element <<EOF
server {
  listen 80;
  server_name $ELEMENT_DOMAIN;
  root /usr/share/element-web;
  index index.html;
}
EOF

ln -sf /etc/nginx/sites-available/matrix /etc/nginx/sites-enabled/matrix
ln -sf /etc/nginx/sites-available/element /etc/nginx/sites-enabled/element

nginx -t && systemctl reload nginx

### SSL
echo "=== Getting SSL certs ==="
certbot --nginx -d "$MATRIX_DOMAIN" -d "$ELEMENT_DOMAIN" -d "$TURN_DOMAIN" --agree-tos -m "$EMAIL" --non-interactive

### TURN
echo "=== Configuring coturn ==="

sed -i -E 's/^[[:space:]]*#?[[:space:]]*TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn

cat > /etc/turnserver.conf <<EOF
listening-port=3478
tls-listening-port=5349

listening-ip=0.0.0.0
relay-ip=$SERVER_IP

fingerprint
use-auth-secret
static-auth-secret=$TURN_SECRET

realm=$TURN_DOMAIN
server-name=$TURN_DOMAIN

cert=/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem
pkey=/etc/letsencrypt/live/$TURN_DOMAIN/privkey.pem

no-loopback-peers
no-multicast-peers
stale-nonce

log-file=/var/log/turn.log
simple-log
EOF

systemctl enable coturn && systemctl restart coturn

### FIREWALL
if command -v ufw &> /dev/null; then
  echo "=== Configuring UFW Firewall ==="
  ufw allow 22
  ufw allow 80
  ufw allow 443
  ufw allow 3478
  ufw allow 5349
  ufw allow 49152:65535/udp
  ufw --force enable
else
  echo "UFW not found. Skipping firewall configuration."
fi

echo "===================================="
echo "✅ INSTALL COMPLETE"
echo "Matrix:  https://$MATRIX_DOMAIN"
echo "Element: https://$ELEMENT_DOMAIN"
echo "TURN:    $TURN_DOMAIN"
echo ""
echo "📱 Element X:"
echo " - Registration ENABLED"
echo " - Calls READY"
echo "===================================="