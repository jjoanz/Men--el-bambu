#!/bin/bash
# Instala el menú de El Bambú en el VPS (Ubuntu + nginx + Postgres + Node 20). Ejecutar como root.
# Es idempotente y NO toca otros sitios ni bases de datos: crea su propio usuario Linux (bambu),
# rol y base de Postgres (bambu / bambu_db), servicio (bambu-api, puerto 3010) y sitio nginx.
#
# Antes: deploy.sh debe haber subido el código a /opt/bambu y el sitio a /var/www/bambu.
# Uso (varios dominios separados por espacio; el primero es el principal):
#   DOMAINS="bambu.konviard.cloud" ./setup-server.sh
#   CERT_NAME=bambu.konviard.cloud DOMAINS="elbamburestaurante.com www.elbamburestaurante.com bambu.konviard.cloud" ./setup-server.sh
# El certificado HTTPS se pide solo para los dominios que ya apuntan a este servidor.
set -euo pipefail

DOMAINS="${DOMAINS:-bambu.konviard.cloud}"
PRIMARY="${DOMAINS%% *}"
CERT_NAME="${CERT_NAME:-$PRIMARY}"   # nombre del certificado (con --expand se le agregan dominios)
APP=/opt/bambu
WEB=/var/www/bambu
DATA=/var/lib/bambu
ENVF=/etc/bambu/bambu.env
say() { echo; echo "==> $*"; }
pg() { (cd /tmp && runuser -u postgres -- psql -v ON_ERROR_STOP=1 "$@"); }
as_bambu() { runuser -l bambu -c "set -a; . $ENVF; set +a; cd $APP; $1"; }

[ "$(id -u)" = 0 ] || { echo "Ejecuta como root"; exit 1; }
[ -f "$APP/server/server.js" ] || { echo "Falta $APP/server/server.js: sube primero el código con deploy.sh"; exit 1; }

say "Usuario y carpetas"
id bambu >/dev/null 2>&1 || useradd -m -s /bin/bash bambu
install -d -o bambu -g bambu -m 755 "$APP" "$WEB" "$DATA" "$DATA/uploads"

say "Base de datos (rol bambu / base bambu_db)"
if [ ! -f "$ENVF" ]; then
  PW=$(openssl rand -hex 24)
  if [ "$(pg -Atc "select 1 from pg_roles where rolname='bambu'")" = 1 ]; then
    pg -qc "alter role bambu login password '$PW'"
  else
    pg -qc "create role bambu login password '$PW'"
  fi
  install -d -m 750 -o root -g bambu /etc/bambu
  ( umask 077; cat > "$ENVF" <<EOF
DATABASE_URL=postgres://bambu:$PW@127.0.0.1:5432/bambu_db
PORT=3010
UPLOAD_DIR=$DATA/uploads
COOKIE_SECURE=true
EOF
  )
  chown root:bambu "$ENVF"; chmod 640 "$ENVF"
fi
sed -i '/^PUBLIC_URL=/d' "$ENVF"   # las fotos se sirven con ruta relativa (mismo dominio)
[ "$(pg -Atc "select 1 from pg_database where datname='bambu_db'")" = 1 ] || pg -qc "create database bambu_db owner bambu"
as_bambu 'psql "$DATABASE_URL" -Atc "select 1" >/dev/null' && echo "conexión a Postgres OK"

say "Tablas y menú inicial"
as_bambu 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f db/schema.sql -f db/seed.sql 2>&1 | grep -v NOTICE || true'
echo "categorías: $(as_bambu 'psql "$DATABASE_URL" -Atc "select count(*) from categories"')"
echo "productos:  $(as_bambu 'psql "$DATABASE_URL" -Atc "select count(*) from products"')"

say "Dependencias de Node"
as_bambu 'npm ci --omit=dev --no-audit --no-fund 2>&1 | tail -2'

say "Servicio bambu-api"
cat > /etc/systemd/system/bambu-api.service <<'EOF'
[Unit]
Description=El Bambú - API del menú
After=network.target postgresql.service

[Service]
User=bambu
Group=bambu
WorkingDirectory=/opt/bambu
EnvironmentFile=/etc/bambu/bambu.env
ExecStart=/usr/bin/node server/server.js
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/var/lib/bambu

[Install]
WantedBy=multi-user.target
EOF
# el usuario bambu puede reiniciar SOLO su servicio (para deploy.sh)
echo 'bambu ALL=(root) NOPASSWD: /usr/bin/systemctl restart bambu-api, /usr/bin/systemctl status bambu-api' > /etc/sudoers.d/bambu
chmod 440 /etc/sudoers.d/bambu; visudo -cf /etc/sudoers.d/bambu >/dev/null
systemctl daemon-reload
systemctl enable bambu-api >/dev/null 2>&1
systemctl restart bambu-api
sleep 2
systemctl is-active bambu-api
curl -fsS http://127.0.0.1:3010/api/health && echo

say "Usuario administrador del panel"
if [ "$(as_bambu 'psql "$DATABASE_URL" -Atc "select count(*) from admin_users"')" = 0 ]; then
  as_bambu 'node server/create-admin.js admin'
else
  echo "ya existe un administrador (para cambiar su clave: node server/create-admin.js admin <clave>)"
fi

say "nginx ($DOMAINS)"
cat > /etc/nginx/sites-available/bambu <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAINS;

    root $WEB;
    index index.html;
    client_max_body_size 8m;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "same-origin" always;

    location ~ /\. { deny all; }

    location /api/ {
        proxy_pass http://127.0.0.1:3010;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
    }

    location /uploads/ {
        alias $DATA/uploads/;
        access_log off;
        expires 365d;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff" always;
        try_files \$uri =404;
    }

    location /img/ {
        expires 30d;
        add_header Cache-Control "public";
        add_header X-Content-Type-Options "nosniff" always;
    }

    location = /admin { return 302 /admin.html; }

    location / {
        add_header Cache-Control "no-cache" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "same-origin" always;
        try_files \$uri \$uri/ =404;
    }
}
EOF
ln -sf /etc/nginx/sites-available/bambu /etc/nginx/sites-enabled/bambu
nginx -t
systemctl reload nginx

say "Respaldos diarios (3:30 am, se guardan 14 días)"
cat > /usr/local/bin/bambu-backup <<'EOF'
#!/bin/bash
set -euo pipefail
D=/var/backups/bambu
install -d -m 700 "$D"
ts=$(date +%Y%m%d-%H%M)
(cd /tmp && runuser -u postgres -- pg_dump bambu_db) | gzip > "$D/db-$ts.sql.gz"
tar czf "$D/uploads-$ts.tar.gz" -C /var/lib/bambu uploads
find "$D" -type f -mtime +14 -delete
EOF
chmod 755 /usr/local/bin/bambu-backup
echo '30 3 * * * root /usr/local/bin/bambu-backup >> /var/log/bambu-backup.log 2>&1' > /etc/cron.d/bambu-backup
chmod 644 /etc/cron.d/bambu-backup
/usr/local/bin/bambu-backup && ls -la /var/backups/bambu | tail -3

say "Certificado HTTPS (solo dominios que ya apuntan a este servidor)"
MYIP=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
READY=(); PENDING=()
for d in $DOMAINS; do
  if getent ahostsv4 "$d" | awk '{print $1}' | grep -qx "$MYIP"; then READY+=(-d "$d"); else PENDING+=("$d"); fi
done
if [ ${#READY[@]} -gt 0 ]; then
  certbot --nginx --cert-name "$CERT_NAME" "${READY[@]}" --expand --non-interactive --agree-tos --register-unsafely-without-email --redirect
fi
[ ${#PENDING[@]} -eq 0 ] || echo "AVISO: aún no apuntan a este servidor (sin HTTPS todavía): ${PENDING[*]}. Cuando apunten, vuelve a correr este script."

say "Listo"
systemctl is-active bambu-api nginx postgresql | tr '\n' ' '; echo
if curl -fsS --resolve "$PRIMARY:443:127.0.0.1" "https://$PRIMARY/api/health" 2>/dev/null; then echo " <- HTTPS OK"
else curl -fsS -H "Host: $PRIMARY" http://127.0.0.1/api/health && echo " <- HTTP OK (sin certificado todavía)"; fi
