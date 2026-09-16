# 📱 Distribuidora Paucara - Gestor de Inventario (Flutter)

Un **CRUD completo de productos** con autenticación, desarrollado en **Flutter** con arquitectura **MVC de 3 capas**.

---

## 🎯 Características

✅ **Autenticación**
- Login/Logout con JWT
- Registro de usuarios
- Almacenamiento seguro de tokens

✅ **Gestión de Productos**
- Listar productos (paginado)
- Crear nuevo producto
- Editar producto existente
- Eliminar producto
- Buscar en tiempo real
- Ver detalles completos

✅ **Interfaz Moderna**
- Tema automático (light/dark)
- Material Design 3
- Responsive design
- Indicadores de carga
- Mensajes de error/éxito

---

## 📁 Archivos Creados

### ✅ Configuración
- `lib/config/env_config.dart` - Configuración del ambiente

### ✅ Modelos
- `lib/models/producto.dart` - Modelo de producto
- `lib/models/login_response.dart` - Modelo de login

### ✅ Servicios (API)
- `lib/services/api_service.dart` - API de productos
- `lib/services/auth_service.dart` - API de autenticación

### ✅ Proveedores (State)
- `lib/providers/auth_provider.dart` - Gestión de autenticación
- `lib/providers/producto_provider.dart` - Gestión de productos

### ✅ Vistas (UI)
- `lib/views/splash_screen.dart` - Pantalla de carga
- `lib/views/login_screen.dart` - Login
- `lib/views/productos_list_screen.dart` - Listado
- `lib/views/producto_form_screen.dart` - Crear/Editar

### ✅ Punto de entrada
- `lib/main.dart` - App principal con MultiProvider

### ✅ Documentación
- `QUICK_START.md` - Guía rápida
- `CRUD_GUIDE.md` - Documentación completa
- `ARCHITECTURE.md` - Arquitectura y diagramas
- `FILES_SUMMARY.md` - Resumen de archivos

---

## 🚀 Instalación Rápida

### 1. Instalar dependencias
```bash
flutter pub get
```

### 2. Ejecutar
```bash
flutter run
```

### 3. Login
```
Email:    usuario@example.com
Password: password123
```

---

## 📊 Estructura MVC

```
┌─────────────────────────────────────┐
│      Views (UI Layer)               │
│  splash, login, list, form          │
└──────────────┬──────────────────────┘
               │ notifyListeners()
┌──────────────▼──────────────────────┐
│  Providers (Logic Layer)            │
│  auth, producto                     │
└──────────────┬──────────────────────┘
               │ API calls
┌──────────────▼──────────────────────┐
│  Services (Data Layer)              │
│  auth_service, api_service          │
└──────────────┬──────────────────────┘
               │ HTTP
┌──────────────▼──────────────────────┐
│  Backend API (Laravel)              │
│  /api/productos, /api/login, etc    │
└─────────────────────────────────────┘
```

---

## ✨ Operaciones CRUD

### 📋 Listar
```dart
await context.read<ProductoProvider>().getProductos();
```

### ➕ Crear
```dart
final producto = Producto(nombre: 'Laptop', activo: true);
await context.read<ProductoProvider>().createProducto(producto);
```

### ✏️ Editar
```dart
await context.read<ProductoProvider>().updateProducto(id, producto);
```

### 🗑️ Eliminar
```dart
await context.read<ProductoProvider>().deleteProducto(id);
```

### 🔍 Buscar
```dart
await context.read<ProductoProvider>().searchProductos('laptop');
```

---

## 🛠️ Endpoints API

```
POST   /api/login              Login
POST   /api/logout             Logout
GET    /api/productos          Listar
GET    /api/productos/:id      Obtener
POST   /api/productos          Crear
PUT    /api/productos/:id      Actualizar
DELETE /api/productos/:id      Eliminar
GET    /api/productos?q=...    Buscar
```

---

## 📚 Documentación

| Archivo | Descripción |
|---------|------------|
| `QUICK_START.md` | Instalación y primeros pasos |
| `CRUD_GUIDE.md` | Guía completa de uso |
| `ARCHITECTURE.md` | Diagramas y arquitectura |
| `FILES_SUMMARY.md` | Lista completa de archivos |

---

## 🎉 Listo para Usar

¡La app está lista! Puedes:
- Comenzar a desarrollar
- Agregar más funcionalidades
- Publicar en app stores

**¡Éxito! 🚀**
