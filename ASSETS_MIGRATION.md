# 🔄 Migración de Scripts de Assets - Completada

## 📋 Resumen de Cambios

Se ha migrado el sistema de regeneración de assets de Odoo de scripts locales a un sistema centralizado desde api-dev.

## ✅ Cambios Realizados

### 1. **Backend** (`/home/go/api-dev/backend/services/instance_manager.py`)

**Antes:**
```python
script_path = os.path.join(instance_path, 'regenerate-assets.sh')
process = subprocess.Popen(['/bin/bash', script_path], ...)
```

**Después:**
```python
centralized_script = '/home/go/api-dev/scripts/odoo/regenerate-assets.sh'
environment = 'develop' if '/develop/' in instance_path else 'production'
process = subprocess.Popen(['/bin/bash', centralized_script, '--force', instance_name, environment], ...)
```

### 2. **Script Centralizado**

- **Ubicación**: `/home/go/api-dev/scripts/odoo/regenerate-assets.sh`
- **Comando global**: `regenerate-assets` (enlace simbólico en `/usr/local/bin/`)
- **Auto-detección**: Detecta automáticamente instancia y ambiente desde el directorio actual

### 3. **Scripts Locales Deprecados**

- `/home/go/apps/develop/odoo/dev-mtg/regenerate-assets.sh` → Mensaje de deprecación
- `/home/go/apps/production/odoo/production/regenerate-assets.sh` → Eliminado

## 🎯 Beneficios

1. **✅ Centralización**: Un solo script para todas las instancias
2. **✅ Mantenimiento**: Cambios en un solo lugar
3. **✅ Consistencia**: Mismo comportamiento en todas las instancias
4. **✅ Auto-detección**: Funciona desde cualquier directorio de instancia
5. **✅ Flexibilidad**: Múltiples formas de ejecutar el script

## 🚀 Formas de Uso

### Desde el Frontend/Backend (automático)
- Los botones en la interfaz web funcionan automáticamente
- El backend usa el script centralizado con `--force`

### Manual desde terminal

1. **Auto-detección** (recomendado):
   ```bash
   cd /home/go/apps/production/odoo/production
   regenerate-assets
   ```

2. **Comando global con parámetros**:
   ```bash
   regenerate-assets production production
   regenerate-assets dev-mtg develop
   ```

3. **Script directo**:
   ```bash
   /home/go/api-dev/scripts/odoo/regenerate-assets.sh production production
   ```

## 🔧 Opciones Disponibles

- `--dry-run`: Ver qué haría sin ejecutar
- `--force`: No pedir confirmación (usado por el backend)
- `-m module_name`: Solo regenerar assets de un módulo específico
- `--help`: Ver ayuda completa

## 📊 Estado Actual

- ✅ Backend actualizado y funcionando
- ✅ Frontend sin cambios necesarios (usa endpoints del backend)
- ✅ Script centralizado operativo
- ✅ Auto-detección funcionando
- ✅ Comando global disponible

## 🎉 Resultado

**Antes**: Cada instancia tenía su propio script → Mantenimiento duplicado
**Después**: Un script centralizado → Mantenimiento unificado y funcionalidad mejorada

Los botones de "Regenerar Assets" en el frontend ahora funcionan correctamente tanto para desarrollo como para producción, usando el sistema centralizado.
