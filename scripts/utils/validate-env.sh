#!/bin/bash

# ========================================
# SCRIPT PARA VALIDAR VARIABLES DE ENTORNO
# ========================================
# Este script valida que las variables requeridas estén definidas
# Uso: ./validate-env.sh [--full] [VAR1 VAR2 VAR3]
#   o: source validate-env.sh [--full] [VAR1 VAR2 VAR3]

# Determinar el directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar variables de entorno solo si se ejecuta directamente (no con source desde otro script)
# Si PROJECT_ROOT ya está definido, significa que otro script ya cargó las variables
if [ -z "$PROJECT_ROOT" ]; then
    if [ -f "$SCRIPT_DIR/../../.env" ]; then
        source "$SCRIPT_DIR/load-env.sh"
    else
        echo "⚠️  Advertencia: No se encontró el archivo .env"
        echo "   Ejecuta: ./quickstart.sh para configurar el sistema"
    fi
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detectar si se pasa el flag --full
RUN_FULL_VALIDATION=false
if [[ "$1" == "--full" ]]; then
    RUN_FULL_VALIDATION=true
    shift  # Remover --full de los argumentos
fi

# Variables a validar (pasadas como argumentos)
REQUIRED_VARS=("$@")

# Si no se pasan argumentos, validar las variables críticas por defecto
if [ ${#REQUIRED_VARS[@]} -eq 0 ]; then
    REQUIRED_VARS=(
        "PROJECT_ROOT"
        "DB_USER"
        "DB_PASSWORD"
        "CF_API_TOKEN"
        "DOMAIN_ROOT"
        "PUBLIC_IP"
    )
fi

# Función para validar una variable
validate_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}❌ Error: La variable $var_name no está definida o está vacía${NC}"
        return 1
    else
        # No mostrar el valor completo de variables sensibles
        if [[ "$var_name" == *"PASSWORD"* ]] || [[ "$var_name" == *"TOKEN"* ]] || [[ "$var_name" == *"SECRET"* ]]; then
            echo -e "${GREEN}✓${NC} $var_name: [CONFIGURADO]"
        else
            echo -e "${GREEN}✓${NC} $var_name: $var_value"
        fi
        return 0
    fi
}

# Validar todas las variables
echo "🔍 Validando variables de entorno..."
echo "=================================="

VALIDATION_FAILED=0

for var in "${REQUIRED_VARS[@]}"; do
    if ! validate_var "$var"; then
        VALIDATION_FAILED=1
    fi
done

echo "=================================="

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo -e "${RED}❌ Validación fallida. Por favor, configura las variables faltantes en el archivo .env${NC}"
    echo -e "${YELLOW}💡 Tip: Ejecuta './quickstart.sh' para configurar el sistema automáticamente${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Todas las variables requeridas están configuradas${NC}"
fi

# Validaciones adicionales opcionales
validate_paths() {
    echo ""
    echo "📁 Validando rutas del sistema..."
    echo "=================================="
    
    # Verificar que existen las rutas críticas
    local paths_ok=1
    
    if [ ! -d "$PROJECT_ROOT" ]; then
        echo -e "${RED}❌ El directorio del proyecto no existe: $PROJECT_ROOT${NC}"
        paths_ok=0
    else
        echo -e "${GREEN}✓${NC} Directorio del proyecto: $PROJECT_ROOT"
    fi
    
    if [ ! -d "$PROD_ROOT" ]; then
        echo -e "${YELLOW}⚠️  El directorio de producción no existe: $PROD_ROOT${NC}"
        echo "   (Se creará cuando se instale la primera instancia)"
    else
        echo -e "${GREEN}✓${NC} Directorio de producción: $PROD_ROOT"
    fi
    
    if [ ! -f "$ODOO_REPO_PATH" ]; then
        echo -e "${YELLOW}⚠️  El archivo del repositorio Odoo no existe: $ODOO_REPO_PATH${NC}"
        echo "   (Necesario para crear nuevas instancias)"
    else
        echo -e "${GREEN}✓${NC} Repositorio Odoo: $ODOO_REPO_PATH"
    fi
    
    echo "=================================="
    
    return $paths_ok
}

# Validar conectividad
validate_connectivity() {
    echo ""
    echo "🌐 Validando conectividad..."
    echo "=================================="
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c '\q' 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Conexión a PostgreSQL exitosa"
        else
            echo -e "${YELLOW}⚠️  No se pudo conectar a PostgreSQL${NC}"
            echo "   Verifica las credenciales en el archivo .env"
        fi
    else
        echo -e "${YELLOW}⚠️  psql no está instalado${NC}"
    fi
    
    # Verificar Cloudflare API
    if [ ! -z "$CF_API_TOKEN" ] && [ ! -z "$CF_ZONE_NAME" ]; then
        CF_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE_NAME" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json")
        
        if echo "$CF_RESPONSE" | grep -q '"success":true'; then
            echo -e "${GREEN}✓${NC} Conexión a Cloudflare API exitosa"
        else
            echo -e "${YELLOW}⚠️  No se pudo verificar la API de Cloudflare${NC}"
            echo "   Verifica el token y el nombre de zona"
        fi
    fi
    
    echo "=================================="
}

# Si se ejecuta con el flag --full, hacer validaciones completas
if [ "$RUN_FULL_VALIDATION" = true ]; then
    validate_paths
    validate_connectivity
fi
