# 🛠️ Scripts Centralizados - API-DEV

Este directorio contiene scripts centralizados para la gestión de servicios y aplicaciones.

## 📁 Estructura

```
scripts/
├── odoo/                   # Scripts para gestión de Odoo
│   ├── regenerate-assets.sh  # Script principal para regenerar assets
│   └── assets               # Wrapper corto
└── README.md               # Este archivo
```

## 🎯 Filosofía

**Todo centralizado desde api-dev**: Los scripts están diseñados para ejecutarse desde este directorio central, evitando duplicación y manteniendo consistencia.

## 🔧 Scripts Disponibles

### 📊 Odoo - Regenerar Assets

**Ubicación**: `odoo/regenerate-assets.sh`

**Descripción**: Script inteligente para regenerar assets de cualquier instancia de Odoo.

#### 🚀 Formas de uso:

1. **🎯 Auto-detección** (recomendado):
   ```bash
   # Desde cualquier directorio de instancia
   cd /home/go/apps/production/odoo/production
   regenerate-assets
   
   cd /home/go/apps/develop/odoo/dev-mtg  
   regenerate-assets --dry-run
   ```

2. **📍 Comando global**:
   ```bash
   regenerate-assets production production
   regenerate-assets dev-mtg develop --force
   ```

3. **🎛️ Script directo**:
   ```bash
   /home/go/api-dev/scripts/odoo/regenerate-assets.sh production production
   /home/go/api-dev/scripts/odoo/assets dev-mtg develop
   ```

#### ⚡ Opciones principales:

- `--dry-run`: Ver qué haría sin ejecutar
- `--force`: No pedir confirmación
- `-m module_name`: Solo regenerar assets de un módulo específico
- `--help`: Ver ayuda completa

#### 🎨 Características:

- ✅ **Auto-detección** de instancia desde directorio actual
- 🎯 **Validaciones** completas de directorios y servicios
- 🎨 **Output colorizado** con timestamps
- 🛡️ **Modo dry-run** para pruebas seguras
- 📊 **Soporte multi-ambiente** (develop/production)

## 🔗 Enlaces Simbólicos

Los scripts están disponibles globalmente mediante enlaces simbólicos en `/usr/local/bin/`:

```bash
regenerate-assets -> /home/go/api-dev/scripts/odoo/regenerate-assets.sh
```

## 📋 Mejores Prácticas

### ✅ Recomendado:

```bash
# Auto-detección (más simple)
cd /home/go/apps/production/odoo/production
regenerate-assets --dry-run

# Comando global con parámetros explícitos
regenerate-assets production production --force
```

### ❌ Evitar:

```bash
# NO crear scripts duplicados en cada instancia
# NO modificar scripts de instancias individuales
# NO hardcodear rutas específicas
```

## 🔄 Migración de Scripts Existentes

Si tienes scripts antiguos en instancias individuales:

1. **Verifica** que el script centralizado cubra tu caso de uso
2. **Actualiza** tus procesos para usar el script centralizado
3. **Marca como deprecado** o elimina el script local
4. **Documenta** el cambio en tu equipo

### Ejemplo de script deprecado:

```bash
#!/bin/bash
echo "⚠️  SCRIPT DEPRECADO"
echo "Usa: regenerate-assets production production"
```

## 🆘 Solución de Problemas

### "Script no encontrado"

```bash
# Verificar que existe el enlace simbólico
ls -la /usr/local/bin/regenerate-assets

# Si no existe, recrear:
sudo ln -sf /home/go/api-dev/scripts/odoo/regenerate-assets.sh /usr/local/bin/regenerate-assets
```

### "No se puede detectar instancia"

```bash
# Verificar que estás en un directorio de instancia válido
pwd
# Debe ser: /home/go/apps/{ambiente}/odoo/{instancia}

# O usar parámetros explícitos:
regenerate-assets mi-instancia develop
```

## 📚 Documentación Adicional

- **Scripts de Odoo**: Ver `odoo/regenerate-assets.sh --help`
- **Comandos generales**: Ver `/home/go/api-dev/docs/COMMANDS.md`

---

💡 **Tip**: Siempre usa `--dry-run` primero para verificar qué hará el script antes de ejecutarlo en producción.
