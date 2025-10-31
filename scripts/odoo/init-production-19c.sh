#!/bin/bash

# ✅ CONFIGURACIÓN INICIAL
ODOO_ROOT="/home/mtg/apps/production/odoo"
PUERTOS_FILE="$HOME/puertos_ocupados_odoo.txt"
PYTHON="/usr/bin/python3.12"
USER="mtg"
ADMIN_PASSWORD="Phax0r!2614"
ODOO_REPO="https://github.com/odoo/odoo.git"
ODOO_VERSION="19.0"

CF_API_TOKEN="dvaecEAtD8yTHSNfc62uCc0MQ3jPorVckGkBcJh-"
CF_ZONE_NAME="softrigx.com"
CF_EMAIL="info@info.com"

# Validar herramientas necesarias
command -v jq >/dev/null 2>&1 || { echo >&2 "❌ 'jq' no está instalado. Abortando."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "❌ 'curl' no está instalado. Abortando."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo >&2 "❌ 'openssl' no está instalado. Abortando."; exit 1; }
command -v dig >/dev/null 2>&1 || { echo >&2 "❌ 'dig' no está instalado. Install 'dnsutils'. Abortando."; exit 1; }

# ➕ Obtener nombre de instancia y sanitizar
RAW_NAME="$1"
if [[ -z "$RAW_NAME" ]]; then
  echo "❌ Debes pasar el nombre de la instancia como argumento."
  exit 1
fi

INSTANCE=$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
LOG="/tmp/odoo-create-$INSTANCE.log"
exec > >(tee -a "$LOG") 2>&1

# Validar nombre
if [[ ! "$INSTANCE" =~ ^[a-z0-9_-]+$ ]]; then
  echo "❌ Nombre inválido. Solo letras, números, guiones y guiones bajos."
  exit 1
elif [[ -d "$ODOO_ROOT/$INSTANCE" ]]; then
  echo "⚠️  La instancia '$INSTANCE' ya existe. Abortando."
  exit 1
fi

# Cancelación segura
trap cleanup SIGINT
cleanup() {
  echo -e "\n❌ Instalación cancelada."
  [[ -d "$ODOO_ROOT/$INSTANCE" ]] && rm -rf "$ODOO_ROOT/$INSTANCE"
  sudo -u postgres dropdb "$INSTANCE" 2>/dev/null || true
  sudo -u postgres dropuser "$INSTANCE" 2>/dev/null || true
  sed -i "/^$PORT$/d" "$PUERTOS_FILE" 2>/dev/null || true
  exit 1
}

# Verificar si ya existe un log para esta instancia
if [[ -f "$LOG" ]]; then
  echo "⚠️ Log previo encontrado, sobreescribiendo $LOG..."
  rm -f "$LOG"
fi

# 🔎 Buscar puerto libre
for port in $(seq 2000 3000); do
  if ! grep -q "^$port$" "$PUERTOS_FILE" 2>/dev/null && ! lsof -iTCP:$port -sTCP:LISTEN -t >/dev/null; then
    PORT=$port
    echo "$PORT" >> "$PUERTOS_FILE"
    break
  fi
done
[[ -z "$PORT" ]] && echo "❌ No se encontró un puerto libre. Abortando." && exit 1

# 🧪 Generar contraseña segura para usuario DB
DB_PASSWORD=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9!@#%^&*_' | head -c 20)
DB_USER="$INSTANCE"

# 🏗️ Paths
DOMAIN="$INSTANCE.softrigx.com"
BASE_DIR="$ODOO_ROOT/$INSTANCE"
ODOO_LOG="$BASE_DIR/odoo.log"
ODOO_CONF="$BASE_DIR/odoo.conf"
SERVICE_FILE="/etc/systemd/system/odoo19-$INSTANCE.service"
NGINX_CONF="/etc/nginx/sites-available/$INSTANCE"

echo "🌐 Dominio: $DOMAIN"
echo "📁 Carpeta base: $BASE_DIR"
echo "🔌 Puerto: $PORT"

# ☁️ Cloudflare DNS
PUBLIC_IP=$(curl -s ifconfig.me)
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE_NAME" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "🌍 Creando subdominio $DOMAIN..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{
       "type": "A",
       "name": "'"$DOMAIN"'",
       "content": "'"$PUBLIC_IP"'",
       "ttl": 3600,
       "proxied": true
     }' > /dev/null

# Esperar resolución DNS
echo "⏳ Esperando propagación DNS..."
MAX_WAIT=60; SECONDS_WAITED=0; SPINNER='|/-\\'
while (( SECONDS_WAITED < MAX_WAIT )); do
  if dig +short "$DOMAIN" | grep -q "$PUBLIC_IP"; then
    echo -e "\n✅ DNS resuelto correctamente."
    break
  fi
  printf "\r⌛ %02ds esperando... %c" "$SECONDS_WAITED" "${SPINNER:SECONDS_WAITED%4:1}"
  sleep 1
  ((SECONDS_WAITED++))
done

# Crear estructura
mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit 1

mkdir -p "$BASE_DIR/custom_addons"

# Enlazar addons personalizados globales si existen
GLOBAL_CUSTOM="/home/mtg/apps/custom_addons_global"
if [[ -d "$GLOBAL_CUSTOM" ]]; then
  ln -s "$GLOBAL_CUSTOM"/* "$BASE_DIR/custom_addons/" 2>/dev/null || true
fi

echo "⬇️ Clonando Odoo..."
git clone --depth 1 --branch $ODOO_VERSION $ODOO_REPO odoo-server

echo "🐍 Entorno virtual..."
$PYTHON -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel
pip install -r odoo-server/requirements.txt

echo "🛢️ Creando usuario PostgreSQL..."
if ! sudo -u postgres psql -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"; then
  echo "❌ Error creando el usuario de base de datos '$DB_USER'. Abortando."
  cleanup
fi

echo "🛢️ Creando base de datos PostgreSQL..."
if ! sudo -u postgres createdb "$INSTANCE" -O "$DB_USER" --encoding='UTF8'; then
  echo "❌ Error creando la base de datos '$INSTANCE'. Abortando."
  sudo -u postgres dropuser "$DB_USER" 2>/dev/null || true
  cleanup
fi

# Dar permisos de uso en el esquema public (necesario para Odoo)
sudo -u postgres psql -d "$INSTANCE" -c "GRANT USAGE, CREATE ON SCHEMA public TO \"$DB_USER\";"
sudo -u postgres psql -d "$INSTANCE" -c "GRANT USAGE ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d "$INSTANCE" -c "ALTER ROLE \"$DB_USER\" SET client_encoding TO 'utf8';"
sudo -u postgres psql -d "$INSTANCE" -c "ALTER ROLE \"$DB_USER\" SET timezone TO 'America/Argentina/Buenos_Aires';"
# Garantizar permisos sobre el esquema public
sudo -u postgres psql -d "$INSTANCE" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"
sudo -u postgres psql -d "$INSTANCE" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"$DB_USER\";"

echo "📝 Configuración Odoo..."
cat > "$ODOO_CONF" <<EOF
[options]
addons_path = $BASE_DIR/odoo-server/addons,$BASE_DIR/custom_addons
db_host = localhost
db_port = 5432
db_user = $DB_USER
db_password = $DB_PASSWORD
db_name = $INSTANCE
log_level = info
logfile = $ODOO_LOG
http_port = $PORT
http_interface = 127.0.0.1
proxy_mode = True
admin_passwd = $ADMIN_PASSWORD
EOF

echo "🧩 Cargando módulo base..."
"$BASE_DIR/venv/bin/python3" "$BASE_DIR/odoo-server/odoo-bin" --load=web -d "$INSTANCE" -c "$ODOO_CONF" --stop-after-init --language=es_AR
"$BASE_DIR/venv/bin/python3" "$BASE_DIR/odoo-server/odoo-bin" -c "$ODOO_CONF" -i base --load-language=es_AR --without-demo=all --stop-after-init

echo "🛠️ Permisos..."
touch "$ODOO_LOG"
chown $USER:$USER "$ODOO_LOG"
chown -R $USER:$USER "$BASE_DIR"

echo "⚙️ Servicio systemd..."
SERVICE_CONFIG="[Unit]
Description=Odoo 19.0 - $INSTANCE
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
Group=$USER
ExecStart=$BASE_DIR/venv/bin/python3 $BASE_DIR/odoo-server/odoo-bin -c $ODOO_CONF
Restart=always

[Install]
WantedBy=multi-user.target"
echo "$SERVICE_CONFIG" | sudo tee /etc/systemd/system/odoo19-${INSTANCE}.service > /dev/null

# Recargar systemd y arrancar servicio (requiere privilegios)
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable odoo19-$INSTANCE
sudo systemctl start odoo19-$INSTANCE

echo "🎨 Compilando assets..."
sudo -u $USER "$BASE_DIR/venv/bin/python3" "$BASE_DIR/odoo-server/odoo-bin" -c "$ODOO_CONF" \
  --update=all --without-demo=all --stop-after-init

sudo systemctl restart odoo19-$INSTANCE

echo "🌐 Generando configuración Nginx (inline template)..."

# === Generación INLINE de la conf Nginx para la instancia (NO usa plantilla externa) ===
# Nota: map {...} debe estar dentro del contexto http; los archivos en sites-available se incluyen ahí por defecto.
sudo tee "$NGINX_CONF" > /dev/null <<NGINX_EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_http_version 1.1;
        proxy_read_timeout 720s;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_http_version 1.1;
        proxy_read_timeout 720s;
    }

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
NGINX_EOF

# Activar el sitio y recargar Nginx (usa sudo)
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

# Verificación de certificado antes de nginx -t
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "✅ Certificado generado, verificando configuración Nginx..."
    sudo systemctl reload nginx
else
    echo "⚠️ Certificado aún no generado, omitiendo nginx -t hasta certbot..."
fi

echo "🔐 Solicitando certificado SSL con certbot (si no existe)..."
if ! sudo certbot certificates | grep -q "$DOMAIN"; then
  echo "🔐 Solicitando certificado SSL con certbot (si no existe)..."
  sudo systemctl stop nginx
  sudo certbot certonly --standalone -d $DOMAIN
  sudo systemctl start nginx
fi

# Nueva verificación de certificado luego de certbot
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "✅ Certificado generado, verificando configuración Nginx..."
    sudo nginx -t && sudo systemctl reload nginx
else
    echo "⚠️ Certificado aún no generado, omitiendo nginx -t hasta certbot..."
fi

echo "📄 info-instancia.txt..."
cat > "$BASE_DIR/info-instancia.txt" <<EOF
🔧 Instancia: $INSTANCE
🌍 Dominio: https://$DOMAIN
🛠️ Puerto: $PORT
🗄️ Base de datos: $INSTANCE
👤 Usuario DB: $DB_USER
🔑 Contraseña DB: $DB_PASSWORD
📁 Ruta: $BASE_DIR
📄 Configuración: $ODOO_CONF
📝 Log: $ODOO_LOG
🪵 Log de instalación: $LOG
🧩 Servicio systemd: odoo19-$INSTANCE
🌀 Logs: sudo journalctl -u odoo19-$INSTANCE -n 50 --no-pager
🌐 Nginx: $NGINX_CONF
🕒 Zona horaria: America/Argentina/Buenos_Aires
🌐 IP pública: $PUBLIC_IP
🔁 Reiniciar servicio: sudo systemctl restart odoo19-$INSTANCE
📋 Ver estado:         sudo systemctl status odoo19-$INSTANCE
EOF


echo "✅ Instancia '$INSTANCE' creada con éxito en: https://$DOMAIN"