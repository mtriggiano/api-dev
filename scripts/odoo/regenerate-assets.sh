#!/bin/bash
# Script para regenerar assets de Odoo
# Uso: ./regenerate-assets.sh [instancia] [ambiente]
# Ejemplo: ./regenerate-assets.sh dev-mtg develop

set -e

# Configuración por defecto
DEFAULT_INSTANCE="dev-mtg"
DEFAULT_ENV="develop"

# Parámetros (se asignarán después del parsing de argumentos)
INSTANCE_NAME="$DEFAULT_INSTANCE"
ENVIRONMENT="$DEFAULT_ENV"

# Directorios base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
🎨 Script para Regenerar Assets de Odoo

Uso: $0 [OPCIONES] [INSTANCIA] [AMBIENTE]

ARGUMENTOS:
    INSTANCIA    Nombre de la instancia (default: $DEFAULT_INSTANCE)
    AMBIENTE     Ambiente (develop/production) (default: $DEFAULT_ENV)

OPCIONES:
    -h, --help      Mostrar esta ayuda
    -f, --force     Forzar regeneración sin confirmación
    -m, --modules   Especificar módulos específicos (separados por coma)
    -d, --database  Especificar base de datos específica
    --no-restart    No reiniciar el servicio después
    --dry-run       Mostrar comandos sin ejecutar

EJEMPLOS:
    $0                                    # Auto-detectar instancia desde directorio actual
    $0 dev-mtg develop                    # Regenerar assets para dev-mtg develop
    $0 production production              # Regenerar assets para producción
    $0 -f dev-mtg develop                 # Forzar regeneración sin confirmación
    $0 -m medical_portal dev-mtg develop  # Solo regenerar assets del módulo medical_portal
    $0 --dry-run                          # Ver qué comandos se ejecutarían (auto-detecta)

AUTO-DETECCIÓN:
    Si ejecutas el script sin argumentos desde un directorio de instancia Odoo,
    automáticamente detectará la instancia y ambiente:
    
    cd /home/go/apps/develop/odoo/dev-mtg && regenerate-assets
    cd /home/go/apps/production/odoo/production && regenerate-assets

EOF
}

# Parsear argumentos
FORCE=false
MODULES=""
DATABASE=""
NO_RESTART=false
DRY_RUN=false

# Argumentos posicionales
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -m|--modules)
            MODULES="$2"
            shift 2
            ;;
        -d|--database)
            DATABASE="$2"
            shift 2
            ;;
        --no-restart)
            NO_RESTART=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Función para auto-detectar instancia desde el directorio actual
auto_detect_instance() {
    local current_dir="$(pwd)"
    
    # Verificar si estamos en un directorio de instancia de Odoo
    if [[ "$current_dir" =~ /home/go/apps/([^/]+)/odoo/([^/]+) ]]; then
        local detected_env="${BASH_REMATCH[1]}"
        local detected_instance="${BASH_REMATCH[2]}"
        
        log "🔍 Auto-detección desde directorio actual:"
        log "   Directorio: $current_dir"
        log "   Ambiente detectado: $detected_env"
        log "   Instancia detectada: $detected_instance"
        
        # Solo usar auto-detección si no se proporcionaron argumentos
        if [[ ${#POSITIONAL_ARGS[@]} -eq 0 ]]; then
            ENVIRONMENT="$detected_env"
            INSTANCE_NAME="$detected_instance"
            log "   ✅ Usando configuración auto-detectada"
            return 0
        else
            log "   ℹ️  Ignorando auto-detección (argumentos proporcionados)"
        fi
    fi
    
    return 1
}

# Procesar argumentos posicionales
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
    INSTANCE_NAME="${POSITIONAL_ARGS[0]}"
fi

if [[ ${#POSITIONAL_ARGS[@]} -gt 1 ]]; then
    ENVIRONMENT="${POSITIONAL_ARGS[1]}"
fi

if [[ ${#POSITIONAL_ARGS[@]} -gt 2 ]]; then
    error "Demasiados argumentos posicionales"
    show_help
    exit 1
fi

# Intentar auto-detección si no se proporcionaron argumentos
if [[ ${#POSITIONAL_ARGS[@]} -eq 0 ]]; then
    auto_detect_instance
fi

# Actualizar BASE_DIR con los parámetros finales
BASE_DIR="/home/go/apps/$ENVIRONMENT/odoo/$INSTANCE_NAME"

# Debug info (solo para dry-run)
if [[ "$DRY_RUN" == true ]]; then
    log "🐛 Debug Info:"
    log "   INSTANCE_NAME: '$INSTANCE_NAME'"
    log "   ENVIRONMENT: '$ENVIRONMENT'"
    log "   BASE_DIR: '$BASE_DIR'"
    log "   POSITIONAL_ARGS: ${POSITIONAL_ARGS[*]}"
fi

# Validaciones
if [[ ! -d "$BASE_DIR" ]]; then
    error "Directorio de instancia no encontrado: $BASE_DIR"
    if [[ "$DRY_RUN" == true ]]; then
        warning "Continuando en modo dry-run..."
    else
        exit 1
    fi
fi

if [[ ! -f "$BASE_DIR/odoo.conf" ]]; then
    error "Archivo de configuración no encontrado: $BASE_DIR/odoo.conf"
    if [[ "$DRY_RUN" == true ]]; then
        warning "Continuando en modo dry-run..."
    else
        exit 1
    fi
fi

if [[ ! -d "$BASE_DIR/venv" ]]; then
    error "Entorno virtual no encontrado: $BASE_DIR/venv"
    if [[ "$DRY_RUN" == true ]]; then
        warning "Continuando en modo dry-run..."
    else
        exit 1
    fi
fi

# Mostrar información
log "🎨 Regenerando assets de Odoo"
log "   Instancia: $INSTANCE_NAME"
log "   Ambiente: $ENVIRONMENT"
log "   Directorio: $BASE_DIR"

if [[ -n "$MODULES" ]]; then
    log "   Módulos específicos: $MODULES"
fi

if [[ -n "$DATABASE" ]]; then
    log "   Base de datos: $DATABASE"
fi

# Función para ejecutar comandos
execute_cmd() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] $description"
        log "[DRY-RUN] Comando: $cmd"
        return 0
    fi
    
    log "$description"
    if eval "$cmd"; then
        success "$description completado"
    else
        error "Falló: $description"
        return 1
    fi
}

# Confirmación
if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
    echo
    warning "⚠️  Esta operación regenerará los assets de Odoo."
    warning "   Esto puede tomar varios minutos y el servicio será reiniciado."
    echo
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log "❌ Operación cancelada por el usuario"
        exit 0
    fi
fi

# Determinar el nombre del servicio
SERVICE_NAME="odoo19e-$INSTANCE_NAME"
if [[ "$ENVIRONMENT" == "production" ]]; then
    SERVICE_NAME="odoo19e-$INSTANCE_NAME"
fi

# Verificar si el servicio existe
if ! systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
    warning "Servicio $SERVICE_NAME no encontrado, continuando sin reiniciar"
    NO_RESTART=true
fi

# Detener servicio
if [[ "$NO_RESTART" != true ]]; then
    execute_cmd "sudo systemctl stop '$SERVICE_NAME'" "⏹️  Deteniendo servicio Odoo ($SERVICE_NAME)"
fi

# Cambiar al directorio de la instancia
execute_cmd "cd '$BASE_DIR'" "📁 Cambiando al directorio de la instancia"

# Activar entorno virtual y regenerar assets
ODOO_CMD="./venv/bin/python3 ./odoo-server/odoo-bin -c ./odoo.conf"

# Agregar parámetros específicos
if [[ -n "$DATABASE" ]]; then
    ODOO_CMD="$ODOO_CMD -d '$DATABASE'"
fi

if [[ -n "$MODULES" ]]; then
    ODOO_CMD="$ODOO_CMD --update='$MODULES'"
else
    ODOO_CMD="$ODOO_CMD --update=all"
fi

ODOO_CMD="$ODOO_CMD --stop-after-init"

execute_cmd "cd '$BASE_DIR' && source venv/bin/activate && $ODOO_CMD" "🎨 Regenerando assets"

# Reiniciar servicio
if [[ "$NO_RESTART" != true ]]; then
    execute_cmd "sudo systemctl start '$SERVICE_NAME'" "▶️  Iniciando servicio Odoo ($SERVICE_NAME)"
    
    # Verificar estado del servicio
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "✅ Servicio $SERVICE_NAME iniciado correctamente"
    else
        error "❌ El servicio $SERVICE_NAME no se pudo iniciar correctamente"
        log "Verificar logs con: sudo journalctl -u $SERVICE_NAME -f"
        exit 1
    fi
fi

success "✅ Assets regenerados correctamente"

# Mostrar información adicional
if [[ "$DRY_RUN" != true ]]; then
    log ""
    log "📋 Información adicional:"
    log "   - Logs del servicio: sudo journalctl -u $SERVICE_NAME -f"
    log "   - Estado del servicio: sudo systemctl status $SERVICE_NAME"
    log "   - Configuración: $BASE_DIR/odoo.conf"
    
    if [[ "$NO_RESTART" != true ]]; then
        log "   - URL probable: http://localhost:$(grep -o 'xmlrpc_port = [0-9]*' "$BASE_DIR/odoo.conf" | cut -d' ' -f3 2>/dev/null || echo '8069')"
    fi
fi
