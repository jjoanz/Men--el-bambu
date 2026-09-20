#!/bin/bash
# Sube el sitio y la API al VPS y reinicia el servicio. Se corre desde tu PC (Git Bash), en cualquier carpeta:
#   deploy/deploy.sh
# Usa una llave SSH exclusiva de despliegue para el usuario "bambu" (sin permisos de root).
set -euo pipefail

HOST="${BAMBU_HOST:-2.25.122.98}"
KEY="${BAMBU_KEY:-$HOME/.ssh/id_bambu_deploy}"
SSH="ssh -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes bambu@$HOST"
cd "$(dirname "$0")/.."

echo "==> Sitio público  -> /var/www/bambu"
tar czf - index.html admin.html config.js menu-fallback.js img | $SSH 'tar xzf - -C /var/www/bambu'

echo "==> API y SQL      -> /opt/bambu"
$SSH 'rm -rf /opt/bambu/server /opt/bambu/db'
tar czf - package.json package-lock.json server db | $SSH 'tar xzf - -C /opt/bambu'

echo "==> Dependencias y reinicio"
$SSH 'cd /opt/bambu && npm ci --omit=dev --no-audit --no-fund 2>&1 | tail -1 && sudo systemctl restart bambu-api'
sleep 2
$SSH 'curl -fsS http://127.0.0.1:3010/api/health' && echo
echo "Listo."
