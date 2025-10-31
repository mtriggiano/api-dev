#!/bin/bash

# ========================================
# SCRIPT DE VERIFICACIÓN RÁPIDA DEL SISTEMA
# ========================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🔍 VERIFICACIÓN RÁPIDA DEL SISTEMA  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Cargar variables de entorno
if [ -f ".env" ]; then
    source scripts/utils/load-env.sh 2>/dev/null
    echo -e "${GREEN}✓${NC} Archivo .env encontrado y cargado"
else
    echo -e "${RED}✗${NC} Archivo .env no encontrado"
    echo -e "${YELLOW}  Ejecuta: ./quickstart.sh${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Configuración Actual:${NC}"
echo "────────────────────────────────────────"
echo -e "  Dominio: ${CYAN}${DOMAIN_ROOT}${NC}"
echo -e "  Panel: ${CYAN}https://${API_DOMAIN}${NC}"
echo -e "  IP Pública: ${CYAN}${PUBLIC_IP}${NC}"
echo -e "  Usuario: ${CYAN}${SYSTEM_USER}${NC}"
echo -e "  Instancia Prod: ${CYAN}${PROD_INSTANCE_NAME}${NC}"
echo ""

# Verificar servicios
echo -e "${BLUE}🔧 Estado de Servicios:${NC}"
echo "────────────────────────────────────────"

# PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓${NC} PostgreSQL: Activo"
    
    # Probar conexión
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d postgres -c '\q' 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Conexión PostgreSQL: OK"
    else
        echo -e "${YELLOW}⚠${NC} Conexión PostgreSQL: Fallo (verificar credenciales)"
    fi
else
    echo -e "${RED}✗${NC} PostgreSQL: Inactivo"
fi

# Nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓${NC} Nginx: Activo"
else
    echo -e "${YELLOW}⚠${NC} Nginx: Inactivo"
fi

# Panel API
if systemctl is-active --quiet server-panel-api 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Panel API: Activo"
else
    echo -e "${YELLOW}⚠${NC} Panel API: No desplegado aún"
fi

echo ""

# Verificar estructura
echo -e "${BLUE}📁 Estructura de Archivos:${NC}"
echo "────────────────────────────────────────"

check_file() {
    if [ -e "$1" ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

check_file ".env" "Archivo .env"
check_file "scripts/odoo/init-production.sh" "Script init-production"
check_file "scripts/odoo/create-dev-instance.sh" "Script create-dev"
check_file "scripts/utils/load-env.sh" "Script load-env"
check_file "scripts/utils/validate-env.sh" "Script validate-env"
check_file "data/puertos_ocupados_odoo.txt" "Archivo de puertos"
check_file "data/dev-instances.txt" "Archivo de instancias dev"

echo ""

# Verificar instancias Odoo
echo -e "${BLUE}🏭 Instancias Odoo:${NC}"
echo "────────────────────────────────────────"

# Producción
if [ -d "$PROD_ROOT" ]; then
    PROD_COUNT=$(ls -1 "$PROD_ROOT" 2>/dev/null | wc -l)
    if [ $PROD_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Producción: $PROD_COUNT instancia(s)"
        ls -1 "$PROD_ROOT" 2>/dev/null | sed 's/^/    - /'
    else
        echo -e "${YELLOW}⚠${NC} Producción: Sin instancias"
    fi
else
    echo -e "${YELLOW}⚠${NC} Producción: Directorio no existe"
fi

# Desarrollo
if [ -d "$DEV_ROOT" ]; then
    DEV_COUNT=$(ls -1 "$DEV_ROOT" 2>/dev/null | wc -l)
    if [ $DEV_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Desarrollo: $DEV_COUNT instancia(s)"
        ls -1 "$DEV_ROOT" 2>/dev/null | sed 's/^/    - /'
    else
        echo -e "${YELLOW}⚠${NC} Desarrollo: Sin instancias"
    fi
else
    echo -e "${YELLOW}⚠${NC} Desarrollo: Directorio no existe"
fi

echo ""

# Verificar backups
echo -e "${BLUE}💾 Backups:${NC}"
echo "────────────────────────────────────────"

if [ -d "$BACKUPS_PATH" ]; then
    BACKUP_COUNT=$(ls -1 "$BACKUPS_PATH"/*.tar.gz 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Backups encontrados: $BACKUP_COUNT"
        LATEST_BACKUP=$(ls -t "$BACKUPS_PATH"/*.tar.gz 2>/dev/null | head -1)
        if [ ! -z "$LATEST_BACKUP" ]; then
            BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
            BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d' ' -f1)
            echo -e "    Último: $(basename "$LATEST_BACKUP") ($BACKUP_SIZE, $BACKUP_DATE)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Sin backups aún"
    fi
else
    echo -e "${YELLOW}⚠${NC} Directorio de backups no existe"
fi

echo ""

# Verificar conectividad
echo -e "${BLUE}🌐 Conectividad:${NC}"
echo "────────────────────────────────────────"

# Cloudflare
if [ ! -z "$CF_API_TOKEN" ]; then
    CF_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN_ROOT" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$CF_RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}✓${NC} Cloudflare API: Conectado"
    else
        echo -e "${YELLOW}⚠${NC} Cloudflare API: Error de conexión"
    fi
else
    echo -e "${YELLOW}⚠${NC} Cloudflare API: Token no configurado"
fi

# Internet
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Internet: Conectado"
else
    echo -e "${RED}✗${NC} Internet: Sin conexión"
fi

echo ""
echo -e "${CYAN}────────────────────────────────────────${NC}"

# Resumen y recomendaciones
echo ""
echo -e "${BLUE}📊 Resumen:${NC}"

ISSUES=0

if ! systemctl is-active --quiet postgresql; then
    echo -e "${YELLOW}  ⚠ PostgreSQL no está activo${NC}"
    ISSUES=$((ISSUES + 1))
fi

if ! systemctl is-active --quiet server-panel-api 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ Panel API no está desplegado${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ ! -d "$PROD_ROOT" ] || [ $(ls -1 "$PROD_ROOT" 2>/dev/null | wc -l) -eq 0 ]; then
    echo -e "${YELLOW}  ⚠ Sin instancias de producción${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}  ✅ Sistema completamente configurado y operativo${NC}"
else
    echo -e "${YELLOW}  ⚠ $ISSUES elemento(s) pendiente(s)${NC}"
    echo ""
    echo -e "${BLUE}Próximos pasos recomendados:${NC}"
    
    if ! systemctl is-active --quiet postgresql; then
        echo "  1. Iniciar PostgreSQL: sudo systemctl start postgresql"
    fi
    
    if ! systemctl is-active --quiet server-panel-api 2>/dev/null; then
        echo "  2. Desplegar panel: ./deploy.sh"
    fi
    
    if [ ! -d "$PROD_ROOT" ] || [ $(ls -1 "$PROD_ROOT" 2>/dev/null | wc -l) -eq 0 ]; then
        echo "  3. Crear instancia producción: ./scripts/odoo/init-production.sh production"
    fi
fi

echo ""
echo -e "${CYAN}Para más información: cat NEXT_STEPS.md${NC}"
echo ""
