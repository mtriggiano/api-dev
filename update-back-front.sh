#!/bin/bash

# Script para actualizar Backend y Frontend de API-DEV
# Uso: ./update-back-front.sh [--backend-only] [--frontend-only] [--force]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para logging con timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para mostrar ayuda
show_help() {
    echo "Script para actualizar Backend y Frontend de API-DEV"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --backend-only    Solo actualizar backend"
    echo "  --frontend-only   Solo actualizar frontend"
    echo "  --force          Forzar actualización sin confirmaciones"
    echo "  --help           Mostrar esta ayuda"
    echo ""
    echo "Sin opciones: Actualiza backend y frontend"
}

# Variables por defecto
UPDATE_BACKEND=true
UPDATE_FRONTEND=true
FORCE_UPDATE=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-only)
            UPDATE_BACKEND=true
            UPDATE_FRONTEND=false
            shift
            ;;
        --frontend-only)
            UPDATE_BACKEND=false
            UPDATE_FRONTEND=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que estamos en el directorio correcto
if [[ ! -d "backend" ]] || [[ ! -d "frontend" ]] || [[ ! -f "frontend/package.json" ]]; then
    log "${RED}❌ Error: Este script debe ejecutarse desde la raíz de api-dev${NC}"
    log "${RED}   Directorio actual: $(pwd)${NC}"
    log "${RED}   Se requieren: backend/, frontend/, frontend/package.json${NC}"
    exit 1
fi

log "${CYAN}🚀 Iniciando actualización de API-DEV${NC}"

if [[ "$UPDATE_BACKEND" == true && "$UPDATE_FRONTEND" == true ]]; then
    log "${BLUE}📋 Modo: Backend + Frontend${NC}"
elif [[ "$UPDATE_BACKEND" == true ]]; then
    log "${BLUE}📋 Modo: Solo Backend${NC}"
else
    log "${BLUE}📋 Modo: Solo Frontend${NC}"
fi

# Función para actualizar backend
update_backend() {
    log "${PURPLE}🔧 Actualizando Backend...${NC}"
    
    # Detener backend si está corriendo
    log "${YELLOW}⏹️  Deteniendo backend...${NC}"
    sudo systemctl stop server-panel-api 2>/dev/null || true
    
    # Instalar dependencias
    log "${BLUE}📦 Instalando dependencias del backend...${NC}"
    cd backend
    if [[ -f "requirements.txt" ]]; then
        if [[ ! -d "venv" ]]; then
            log "${YELLOW}🐍 Creando entorno virtual...${NC}"
            python3 -m venv venv
        fi
        source venv/bin/activate
        pip install -r requirements.txt
        deactivate
    fi
    cd ..
    
    # Reiniciar backend
    log "${GREEN}🚀 Iniciando backend...${NC}"
    sudo systemctl start server-panel-api
    
    # Verificar estado
    sleep 3
    if sudo systemctl is-active --quiet server-panel-api; then
        log "${GREEN}✅ Backend iniciado correctamente${NC}"
    else
        log "${RED}❌ Error al iniciar backend${NC}"
        log "${YELLOW}📋 Logs del backend:${NC}"
        sudo journalctl -u server-panel-api --no-pager -n 10
        return 1
    fi
}

# Función para actualizar frontend
update_frontend() {
    log "${PURPLE}🎨 Actualizando Frontend...${NC}"
    
    # Instalar dependencias
    log "${BLUE}📦 Instalando dependencias del frontend...${NC}"
    cd frontend
    npm install
    
    # Build de producción (Nginx sirve desde dist/)
    log "${GREEN}� Compilando frontend para producción...${NC}"
    npm run build
    
    if [[ -f "dist/index.html" ]]; then
        log "${GREEN}✅ Frontend compilado correctamente${NC}"
        log "${CYAN}� Build en: /home/go/api-dev/frontend/dist/${NC}"
    else
        log "${RED}❌ Error al compilar frontend${NC}"
        cd ..
        return 1
    fi
    
    cd ..
}

# Función para mostrar estado final
show_status() {
    log "${CYAN}📊 Estado de servicios:${NC}"
    
    if [[ "$UPDATE_BACKEND" == true ]]; then
        if sudo systemctl is-active --quiet server-panel-api; then
            log "${GREEN}  ✅ Backend (server-panel-api): ACTIVO${NC}"
        else
            log "${RED}  ❌ Backend (server-panel-api): INACTIVO${NC}"
        fi
    fi
    
    if [[ "$UPDATE_FRONTEND" == true ]]; then
        if [[ -f "/home/go/api-dev/frontend/dist/index.html" ]]; then
            log "${GREEN}  ✅ Frontend (Build): DISPONIBLE${NC}"
        else
            log "${RED}  ❌ Frontend (Build): NO ENCONTRADO${NC}"
        fi
    fi
    
    # Verificar nginx
    if sudo systemctl is-active --quiet nginx; then
        log "${GREEN}  ✅ Nginx: ACTIVO${NC}"
    else
        log "${YELLOW}  ⚠️  Nginx: INACTIVO${NC}"
    fi
}

# Crear directorio de logs si no existe
mkdir -p logs

# Confirmación si no es forzado
if [[ "$FORCE_UPDATE" == false ]]; then
    echo ""
    log "${YELLOW}⚠️  Esto reiniciará los servicios. ¿Continuar? (s/n):${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log "${YELLOW}❌ Actualización cancelada${NC}"
        exit 0
    fi
fi

# Ejecutar actualizaciones
ERROR_OCCURRED=false

if [[ "$UPDATE_BACKEND" == true ]]; then
    if ! update_backend; then
        ERROR_OCCURRED=true
        log "${RED}❌ Error actualizando backend${NC}"
    fi
fi

if [[ "$UPDATE_FRONTEND" == true ]]; then
    if ! update_frontend; then
        ERROR_OCCURRED=true
        log "${RED}❌ Error actualizando frontend${NC}"
    fi
fi

# Mostrar estado final
echo ""
log "${CYAN}🎉 Actualización completada!${NC}"
show_status

# Información útil
echo ""
log "${CYAN}📋 Información útil:${NC}"
if [[ "$UPDATE_BACKEND" == true ]]; then
    log "${CYAN}   Backend API: http://localhost:5000${NC}"
    log "${CYAN}   Logs Backend: sudo journalctl -u server-panel-api -f${NC}"
fi
if [[ "$UPDATE_FRONTEND" == true ]]; then
    log "${CYAN}   Frontend: https://api-dev.hospitalprivadosalta.ar${NC}"
    log "${CYAN}   Build Dir: /home/go/api-dev/frontend/dist/${NC}"
fi
log "${CYAN}   Estado servicios: /home/go/api-dev/restart.sh --status${NC}"
log "${CYAN}   Detener todo: /home/go/api-dev/restart.sh --stop${NC}"

if [[ "$ERROR_OCCURRED" == true ]]; then
    log "${RED}⚠️  Se produjeron errores durante la actualización${NC}"
    exit 1
else
    log "${GREEN}✅ Actualización exitosa${NC}"
    exit 0
fi
