#!/bin/bash
# Script para reiniciar Backend y Frontend de api-dev
# Uso: ./restart.sh [opciones]

set -e

# Directorios
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
🔄 Script para Reiniciar Backend y Frontend - API-DEV

Uso: $0 [OPCIONES]

OPCIONES:
    -h, --help          Mostrar esta ayuda
    -b, --backend-only  Solo reiniciar backend
    -f, --frontend-only Solo reiniciar frontend
    -d, --dev           Modo desarrollo (frontend con npm run dev)
    -p, --production    Modo producción (frontend build + nginx reload)
    --no-deps          No instalar dependencias
    --force            Forzar reinicio sin confirmación
    --status           Solo mostrar estado de los servicios
    --stop             Solo detener servicios
    --start            Solo iniciar servicios

EJEMPLOS:
    $0                  # Reiniciar backend y frontend (modo desarrollo)
    $0 -b               # Solo reiniciar backend
    $0 -f -d            # Solo reiniciar frontend en modo desarrollo
    $0 -p               # Reiniciar en modo producción
    $0 --status         # Ver estado de servicios
    $0 --stop           # Detener todos los servicios
    $0 --start          # Iniciar todos los servicios

SERVICIOS:
    Backend:  server-panel-api (systemd)
    Frontend: npm run dev (desarrollo) / nginx (producción)

EOF
}

# Función para verificar si un proceso está corriendo
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" > /dev/null 2>&1
}

# Función para verificar estado de servicios
check_services_status() {
    log "📊 Estado de servicios:"
    
    # Backend (systemd)
    if systemctl is-active --quiet server-panel-api; then
        success "  ✅ Backend (server-panel-api): ACTIVO"
    else
        error "  ❌ Backend (server-panel-api): INACTIVO"
    fi
    
    # Frontend (desarrollo)
    if is_process_running "vite.*--port.*5173"; then
        success "  ✅ Frontend Dev (Vite): ACTIVO en puerto 5173"
    else
        warning "  ⚠️  Frontend Dev (Vite): INACTIVO"
    fi
    
    # Nginx (producción)
    if systemctl is-active --quiet nginx; then
        success "  ✅ Nginx: ACTIVO"
    else
        warning "  ⚠️  Nginx: INACTIVO"
    fi
    
    # Procesos Python
    local python_procs=$(pgrep -f "python.*app.py" | wc -l)
    if [ "$python_procs" -gt 0 ]; then
        info "  📊 Procesos Python activos: $python_procs"
    fi
    
    # Procesos Node
    local node_procs=$(pgrep -f "node.*vite" | wc -l)
    if [ "$node_procs" -gt 0 ]; then
        info "  📊 Procesos Node/Vite activos: $node_procs"
    fi
}

# Función para detener servicios
stop_services() {
    log "⏹️  Deteniendo servicios..."
    
    if [ "$BACKEND_ONLY" != true ] && [ "$FRONTEND_ONLY" == true ]; then
        # Solo frontend
        log "Deteniendo procesos de frontend..."
        pkill -f "vite.*--port.*5173" 2>/dev/null || true
        success "Frontend detenido"
    elif [ "$FRONTEND_ONLY" != true ] && [ "$BACKEND_ONLY" == true ]; then
        # Solo backend
        log "Deteniendo backend..."
        sudo systemctl stop server-panel-api
        success "Backend detenido"
    else
        # Ambos
        log "Deteniendo backend..."
        sudo systemctl stop server-panel-api || warning "No se pudo detener server-panel-api"
        
        log "Deteniendo procesos de frontend..."
        pkill -f "vite.*--port.*5173" 2>/dev/null || true
        pkill -f "node.*vite" 2>/dev/null || true
        
        success "Todos los servicios detenidos"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    if [ "$NO_DEPS" == true ]; then
        info "Saltando instalación de dependencias (--no-deps)"
        return
    fi
    
    # Backend dependencies
    if [ "$FRONTEND_ONLY" != true ]; then
        log "📦 Instalando dependencias del backend..."
        cd "$BACKEND_DIR"
        if [ ! -d "venv" ]; then
            warning "Entorno virtual no encontrado, creando..."
            python3.12 -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        success "Dependencias del backend instaladas"
    fi
    
    # Frontend dependencies
    if [ "$BACKEND_ONLY" != true ]; then
        log "📦 Instalando dependencias del frontend..."
        cd "$FRONTEND_DIR"
        npm install
        success "Dependencias del frontend instaladas"
    fi
    
    cd "$PROJECT_DIR"
}

# Función para iniciar backend
start_backend() {
    log "🚀 Iniciando backend..."
    
    # Verificar que existe el servicio
    if ! systemctl list-unit-files | grep -q "server-panel-api.service"; then
        error "Servicio server-panel-api no encontrado"
        info "Ejecuta el script de deploy primero: ./deploy.sh"
        return 1
    fi
    
    sudo systemctl start server-panel-api
    
    # Esperar un momento y verificar
    sleep 2
    if systemctl is-active --quiet server-panel-api; then
        success "✅ Backend iniciado correctamente"
        info "   URL: http://localhost:5000"
    else
        error "❌ Error al iniciar el backend"
        info "   Ver logs: sudo journalctl -u server-panel-api -f"
        return 1
    fi
}

# Función para iniciar frontend en modo desarrollo
start_frontend_dev() {
    log "🚀 Iniciando frontend en modo desarrollo..."
    
    cd "$FRONTEND_DIR"
    
    # Verificar si ya está corriendo
    if is_process_running "vite.*--port.*5173"; then
        warning "Frontend ya está corriendo, deteniendo proceso anterior..."
        pkill -f "vite.*--port.*5173" 2>/dev/null || true
        sleep 2
    fi
    
    # Iniciar en background
    nohup npm run dev > "$PROJECT_DIR/logs/frontend-dev.log" 2>&1 &
    local pid=$!
    
    # Esperar un momento para verificar
    sleep 3
    if kill -0 $pid 2>/dev/null; then
        success "✅ Frontend iniciado en modo desarrollo"
        info "   URL: http://localhost:5173"
        info "   PID: $pid"
        info "   Logs: $PROJECT_DIR/logs/frontend-dev.log"
    else
        error "❌ Error al iniciar el frontend"
        info "   Ver logs: cat $PROJECT_DIR/logs/frontend-dev.log"
        return 1
    fi
    
    cd "$PROJECT_DIR"
}

# Función para iniciar frontend en modo producción
start_frontend_prod() {
    log "🚀 Iniciando frontend en modo producción..."
    
    cd "$FRONTEND_DIR"
    
    # Build del frontend
    log "🔨 Construyendo frontend..."
    npm run build
    
    # Recargar nginx
    log "🔄 Recargando Nginx..."
    sudo systemctl reload nginx
    
    if systemctl is-active --quiet nginx; then
        success "✅ Frontend en producción actualizado"
        info "   Nginx recargado correctamente"
    else
        error "❌ Error con Nginx"
        return 1
    fi
    
    cd "$PROJECT_DIR"
}

# Función para iniciar servicios
start_services() {
    log "▶️  Iniciando servicios..."
    
    # Crear directorio de logs si no existe
    mkdir -p "$PROJECT_DIR/logs"
    
    if [ "$FRONTEND_ONLY" == true ]; then
        # Solo frontend
        if [ "$PRODUCTION_MODE" == true ]; then
            start_frontend_prod
        else
            start_frontend_dev
        fi
    elif [ "$BACKEND_ONLY" == true ]; then
        # Solo backend
        start_backend
    else
        # Ambos
        start_backend
        
        if [ "$PRODUCTION_MODE" == true ]; then
            start_frontend_prod
        else
            start_frontend_dev
        fi
    fi
}

# Parsear argumentos
BACKEND_ONLY=false
FRONTEND_ONLY=false
DEV_MODE=true
PRODUCTION_MODE=false
NO_DEPS=false
FORCE=false
STATUS_ONLY=false
STOP_ONLY=false
START_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--backend-only)
            BACKEND_ONLY=true
            shift
            ;;
        -f|--frontend-only)
            FRONTEND_ONLY=true
            shift
            ;;
        -d|--dev)
            DEV_MODE=true
            PRODUCTION_MODE=false
            shift
            ;;
        -p|--production)
            PRODUCTION_MODE=true
            DEV_MODE=false
            shift
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --status)
            STATUS_ONLY=true
            shift
            ;;
        --stop)
            STOP_ONLY=true
            shift
            ;;
        --start)
            START_ONLY=true
            shift
            ;;
        -*)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
        *)
            error "Argumento no reconocido: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validaciones
if [ "$BACKEND_ONLY" == true ] && [ "$FRONTEND_ONLY" == true ]; then
    error "No puedes usar --backend-only y --frontend-only al mismo tiempo"
    exit 1
fi

# Verificar directorios
if [ ! -d "$BACKEND_DIR" ]; then
    error "Directorio backend no encontrado: $BACKEND_DIR"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    error "Directorio frontend no encontrado: $FRONTEND_DIR"
    exit 1
fi

# Mostrar información inicial
log "🔄 Script de Reinicio - API-DEV"
log "   Proyecto: $PROJECT_DIR"
log "   Backend: $BACKEND_DIR"
log "   Frontend: $FRONTEND_DIR"

if [ "$BACKEND_ONLY" == true ]; then
    log "   Modo: Solo Backend"
elif [ "$FRONTEND_ONLY" == true ]; then
    log "   Modo: Solo Frontend"
else
    log "   Modo: Backend + Frontend"
fi

if [ "$PRODUCTION_MODE" == true ]; then
    log "   Ambiente: Producción"
else
    log "   Ambiente: Desarrollo"
fi

echo

# Ejecutar según la opción
if [ "$STATUS_ONLY" == true ]; then
    check_services_status
    exit 0
fi

if [ "$STOP_ONLY" == true ]; then
    stop_services
    check_services_status
    exit 0
fi

if [ "$START_ONLY" == true ]; then
    install_dependencies
    start_services
    echo
    check_services_status
    exit 0
fi

# Flujo completo de reinicio
if [ "$FORCE" != true ]; then
    warning "⚠️  Este script reiniciará los servicios de api-dev"
    if [ "$PRODUCTION_MODE" == true ]; then
        warning "   MODO PRODUCCIÓN: Se hará build del frontend y se recargará Nginx"
    else
        warning "   MODO DESARROLLO: Se iniciará Vite dev server"
    fi
    echo
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log "❌ Operación cancelada por el usuario"
        exit 0
    fi
fi

# Ejecutar reinicio completo
stop_services
install_dependencies
start_services

echo
log "🎉 Reinicio completado!"
check_services_status

# Información adicional
echo
log "📋 Información útil:"
if [ "$BACKEND_ONLY" != true ]; then
    if [ "$PRODUCTION_MODE" != true ]; then
        log "   Frontend Dev: http://localhost:5173"
        log "   Logs Frontend: tail -f $PROJECT_DIR/logs/frontend-dev.log"
    fi
fi

if [ "$FRONTEND_ONLY" != true ]; then
    log "   Backend API: http://localhost:5000"
    log "   Logs Backend: sudo journalctl -u server-panel-api -f"
fi

log "   Estado servicios: $0 --status"
log "   Detener todo: $0 --stop"
