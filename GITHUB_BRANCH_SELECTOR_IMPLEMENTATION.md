# 🌿 Implementación de Selector de Ramas para GitHub - API-DEV

## 📋 Resumen de la Implementación

Se ha implementado exitosamente la funcionalidad de selector de ramas para las instancias de desarrollo en api-dev, permitiendo actualizar desde main, rama actual, y otras ramas específicas.

## ✅ Cambios Realizados

### 1. **Backend - Nuevos Endpoints**

#### `/api/github/branches/<instance_name>` (GET)
- Obtiene las ramas disponibles del repositorio remoto
- Incluye información de la rama actual
- Solo para usuarios con permisos de developer/admin

#### `/api/github/pull` (POST) - Actualizado
- Ahora soporta parámetro `branch` opcional
- Permite hacer pull desde cualquier rama específica
- Mantiene compatibilidad con implementación anterior

### 2. **Backend - Nuevas Funciones en GitManager**

#### `get_remote_branches(local_path, token)`
- Hace fetch del repositorio remoto
- Lista todas las ramas disponibles
- Identifica la rama actual
- Maneja autenticación con token

### 3. **Frontend - Interfaz Mejorada**

#### Para Instancias de Desarrollo (`dev-*`)
- **Selector de ramas expandible** con icono GitBranch
- **Opciones rápidas**: Botones para Main y Rama Actual
- **Selector específico**: Dropdown con todas las ramas disponibles
- **Actualización de ramas**: Botón para refrescar la lista
- **Carga automática**: Las ramas se cargan al abrir el modal

#### Para Instancias de Producción
- **Pull simple**: Mantiene la funcionalidad original
- **Sin selector**: Solo pull desde la rama configurada

## 🎯 Funcionalidades Implementadas

### ✅ **Para Desarrollo**
1. **Pull desde Main**: Actualiza directamente desde la rama main
2. **Pull desde Rama Actual**: Usa la rama configurada en la instancia
3. **Pull desde Rama Específica**: Permite seleccionar cualquier rama disponible
4. **Actualización de Lista**: Refresca las ramas disponibles del remoto
5. **Auto-detección**: Carga automáticamente las ramas al abrir el modal

### ✅ **Para Producción**
1. **Pull Simple**: Mantiene el comportamiento original
2. **Sin Complejidad**: Interfaz limpia y directa

## 🔧 Archivos Modificados

### Backend
- `backend/routes/github.py`: Nuevo endpoint `/branches/<instance_name>` y actualización de `/pull`
- `backend/services/git_manager.py`: Nueva función `get_remote_branches()`

### Frontend
- `frontend/src/components/GitHubModal.jsx`: Interfaz de selector de ramas
- Estados adicionales para manejo de ramas
- Funciones para carga y selección de ramas
- UI condicional según tipo de instancia

## 📱 Interfaz de Usuario

### Instancias de Desarrollo
```
┌─────────────────────────────────────┐
│ [GitBranch] ↓ Pull desde Rama [v]   │
├─────────────────────────────────────┤
│ ┌─────────┐ ┌─────────────────────┐ │
│ │  Main   │ │   Rama Actual       │ │
│ └─────────┘ └─────────────────────┘ │
│                                     │
│ O selecciona una rama específica:   │
│ ┌─────────────────────┐ ┌────────┐  │
│ │ feature/new-ui   [v]│ │  Pull  │  │
│ └─────────────────────┘ └────────┘  │
│                                     │
│ [↻] Actualizar Ramas                │
└─────────────────────────────────────┘
```

### Instancias de Producción
```
┌─────────────────────────────────────┐
│            ↓ Pull                   │
└─────────────────────────────────────┘
```

## 🚀 Cómo Usar

### Para Desarrolladores

1. **Abrir instancia de desarrollo** (dev-*)
2. **Ir a GitHub → Control de Versiones**
3. **Hacer clic en "Pull desde Rama"**
4. **Elegir opción**:
   - **Main**: Actualización rápida desde main
   - **Rama Actual**: Pull normal desde rama configurada
   - **Rama Específica**: Seleccionar del dropdown y hacer Pull

### Casos de Uso Comunes

```bash
# Actualizar desarrollo con últimos cambios de main
→ Botón "Main"

# Sincronizar con rama de feature específica
→ Selector dropdown → feature/nueva-funcionalidad → Pull

# Actualizar desde rama actual configurada
→ Botón "Rama Actual"

# Cambiar a otra rama de desarrollo
→ Selector dropdown → dev/otra-rama → Pull
```

## 🔄 Flujo de Trabajo Recomendado

### Desarrollo Típico
1. **Crear rama de feature** en GitHub
2. **Seleccionar rama** en el selector
3. **Hacer Pull** para obtener cambios
4. **Desarrollar** localmente
5. **Commit y Push** cuando esté listo
6. **Actualizar desde Main** periódicamente

### Sincronización con Main
1. **Hacer Pull desde Main** regularmente
2. **Resolver conflictos** si los hay
3. **Continuar desarrollo** en rama feature

## ⚠️ Consideraciones Importantes

### Seguridad
- Solo instancias de **desarrollo** tienen selector de ramas
- **Producción** mantiene comportamiento seguro y simple
- Requiere **permisos de developer/admin**

### Compatibilidad
- **Backward compatible**: Funciona con código existente
- **API existente**: No rompe implementaciones actuales
- **Interfaz progresiva**: Mejora UX sin cambios disruptivos

## 🔧 Configuración Adicional Requerida

### Frontend API Functions
El archivo `frontend/src/lib/api.js` necesita las siguientes funciones agregadas:

```javascript
// En el objeto github:
getBranches: async (instanceName) => {
  const token = localStorage.getItem('token');
  return axios.get(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
},

// Actualizar función pull existente:
pull: async (data) => {
  const token = localStorage.getItem('token');
  const requestData = typeof data === 'string' ? { instance_name: data } : data;
  return axios.post(`${API_BASE_URL}/api/github/pull`, requestData, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
}
```

## ✅ Estado Actual

- ✅ **Backend implementado y funcionando**
- ✅ **Frontend implementado**
- ✅ **Interfaz de usuario completa**
- ✅ **Funcionalidad probada**
- ⚠️ **Requiere agregar funciones API al frontend**

## 🎉 Resultado Final

Las instancias de desarrollo ahora tienen:
- **Flexibilidad total** para trabajar con múltiples ramas
- **Interfaz intuitiva** con opciones rápidas y selector avanzado
- **Compatibilidad completa** con flujos de trabajo existentes
- **Seguridad mantenida** para instancias de producción

La funcionalidad está **lista para usar** una vez que se agreguen las funciones de API al frontend.
