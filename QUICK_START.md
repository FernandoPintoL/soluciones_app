# 🚀 Quick Start - App Inventario Flutter

## ✅ Requisitos
- Flutter 3.13.1+
- Dart 3.1.0+
- Conexión a servidor: `http://192.168.100.42:8000`

---

## 📦 Instalación

### 1. Instalar dependencias
```bash
cd app_inventario
flutter pub get
```

### 2. Ejecutar app
```bash
flutter run
```

---

## 🔐 Credenciales de Prueba

Usa cualquier usuario creado en tu sistema backend:

```
Email:    tu@email.com
Password: contraseña
```

---

## 📱 Pantallas Disponibles

| Pantalla | Función |
|----------|---------|
| **Login** | Autenticación con email/contraseña |
| **Productos** | Listar, buscar, crear, editar, eliminar |
| **Formulario** | Crear o editar producto |

---

## 🎯 Acciones Principales

### 📋 Listar Productos
1. Login exitoso → Ves lista de productos
2. Scroll para cargar más
3. Click en producto para ver detalles

### ➕ Crear Producto
1. Click botón `+` flotante
2. Llena: Nombre*, SKU, Descripción, etc.
3. Click "Crear"

### ✏️ Editar Producto
1. Click en producto o "Editar" en menú
2. Modifica campos
3. Click "Actualizar"

### 🗑️ Eliminar Producto
1. Click menú (⋮) en producto
2. Selecciona "Eliminar"
3. Confirma en dialog

### 🔍 Buscar
1. Escribe en barra de búsqueda
2. Resultados en tiempo real

---

## 🔧 Configuración

### Cambiar servidor
Editar en `lib/config/env_config.dart`:
```dart
static const String baseUrl = 'tu-servidor:8000/api';
```

---

## 📊 Estructura de Datos

### Producto (JSON)
```json
{
  "id": 1,
  "nombre": "Laptop",
  "sku": "LAP001",
  "descripcion": "Descripción...",
  "peso": 2.5,
  "unidad_medida_id": 1,
  "categoria_id": 1,
  "marca_id": 1,
  "stock_minimo": 5,
  "stock_maximo": 50,
  "activo": true,
  "es_producto_comida": false,
  "permite_venta_sin_stock": false,
  "visible_app": true,
  "es_de_produccion": false
}
```

---

## 🎨 Tema

- **Light**: Interfaz clara
- **Dark**: Modo oscuro automático
- Soporta ambos según preferencia del sistema

---

## 🐛 Troubleshooting

### ❌ "Connection refused"
- Verifica que el servidor esté corriendo
- Comprueba IP en `env_config.dart`

### ❌ "Credenciales inválidas"
- Verifica email/contraseña
- Asegúrate que el usuario existe en la BD

### ❌ "Token expirado"
- Haz logout y vuelve a login
- El token se renueva automáticamente

### ❌ "Error 422"
- Valida que los campos requeridos estén llenos
- Revisa los tipos de datos

---

## 📚 Documentación Completa
Ver: `CRUD_GUIDE.md`

---

**¡Diviértete desarrollando! 🎉**
