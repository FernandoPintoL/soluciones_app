# 🏗️ Arquitectura - App Inventario Flutter

## 📐 Diagrama de Capas

```
┌─────────────────────────────────────────────────────────┐
│                     UI LAYER (VIEWS)                    │
│  (splash_screen, login_screen, productos_list_screen,  │
│           producto_form_screen)                         │
└──────────────────────┬──────────────────────────────────┘
                       │ notifyListeners()
                       ↓
┌─────────────────────────────────────────────────────────┐
│              STATE MANAGEMENT (PROVIDERS)               │
│        (AuthProvider, ProductoProvider)                 │
│                                                         │
│  ├─ isLoading: bool                                    │
│  ├─ isAuthenticated: bool                              │
│  ├─ errorMessage: String?                              │
│  ├─ productos: List<Producto>                          │
│  └─ user: Map<String, dynamic>?                        │
└──────────────────────┬──────────────────────────────────┘
                       │ calls
                       ↓
┌─────────────────────────────────────────────────────────┐
│              BUSINESS LOGIC (SERVICES)                  │
│        (AuthService, ApiService)                        │
│                                                         │
│  ├─ login(email, password)                             │
│  ├─ getProductos()                                     │
│  ├─ createProducto(producto)                           │
│  ├─ updateProducto(id, producto)                       │
│  └─ deleteProducto(id)                                 │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTP requests
                       ↓
┌─────────────────────────────────────────────────────────┐
│              DATA LAYER (BACKEND API)                   │
│                                                         │
│  POST   /api/login                                      │
│  GET    /api/productos                                  │
│  POST   /api/productos                                  │
│  PUT    /api/productos/{id}                             │
│  DELETE /api/productos/{id}                             │
│                                                         │
│  Base URL: http://192.168.100.42:8000/api              │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 Flujo de Datos

### 1. **Lectura (Get)**
```
View (Product List)
    ↓ (onInit)
Provider (getProductos)
    ↓
Service (ApiService)
    ↓ (HTTP GET)
Backend API
    ↓ (JSON)
Service (parseProductos)
    ↓
Provider (updateState)
    ↓ (notifyListeners)
View (rebuild)
```

### 2. **Escritura (Create/Update)**
```
View (Form)
    ↓ (onSubmit)
Provider (createProducto)
    ↓
Service (ApiService)
    ↓ (HTTP POST/PUT)
Backend API
    ↓ (Validation)
Backend (Save)
    ↓ (JSON Response)
Service (parseResponse)
    ↓
Provider (updateState)
    ↓ (notifyListeners)
View (rebuild + navigate)
```

### 3. **Eliminación (Delete)**
```
View (ConfirmDialog)
    ↓ (onConfirm)
Provider (deleteProducto)
    ↓
Service (ApiService)
    ↓ (HTTP DELETE)
Backend API
    ↓ (Delete)
Backend (Removed)
    ↓ (Response 204)
Service (parseResponse)
    ↓
Provider (updateState)
    ↓ (notifyListeners)
View (rebuild)
```

---

## 🔐 Flujo de Autenticación

```
Login Screen
    ↓ (email, password)
AuthProvider.login()
    ↓
AuthService.login()
    ↓ (POST /api/login)
Backend API
    ↓ (Validate credentials)
Backend (Generate Token)
    ↓ (JSON: {token, user})
AuthService (SaveToken + SaveUser)
    ↓ (SharedPreferences)
Local Storage
    ↓
AuthProvider (updateState)
    ↓ (notifyListeners)
Navigation (to ProductosListScreen)
```

---

## 🌐 Comunicación HTTP

### Headers
```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <token>  (incluido automáticamente)
```

### Request/Response Flow
```
Request:
  POST /api/productos
  Headers: {Authorization: Bearer token, Content-Type: application/json}
  Body: {nombre, sku, descripcion, ...}

Response (201 Created):
  {
    "success": true,
    "data": {
      "id": 1,
      "nombre": "...",
      ...
    }
  }

Error Response (422):
  {
    "message": "Error de validación",
    "errors": {
      "nombre": ["El nombre es requerido"]
    }
  }
```

---

## 📦 Clase Producto

```dart
class Producto {
  final int id;
  final String nombre;
  final String? sku;
  final String? descripcion;
  final double? peso;
  final int? unidadMedidaId;
  final int? categoriaId;
  final int? marcaId;
  final int? proveedorId;
  final int stockMinimo;
  final int stockMaximo;
  final bool activo;
  final bool esProductoComida;
  final bool permitirVentaSinStock;
  final bool esProductoAdicional;
  final bool puedeRecbirProductoAdicional;
  final bool visibleApp;
  final bool esDeProduccion;
  final double? limiteventa;
  final String? principioActivo;
  final String? usoMedicacion;
  final DateTime? fechaCreacion;
  
  // Methods
  factory Producto.fromJson(Map<String, dynamic> json)
  Map<String, dynamic> toJson()
}
```

---

## 🔗 Relación Provider-Service

```
┌─────────────────────────┐
│   ProductoProvider      │
├─────────────────────────┤
│ - _apiService           │◄──────────┐
│ - _authService          │           │
│ - _productos: List      │           │
│ - _isLoading: bool      │           │
│                         │           │
│ Methods:                │           │
│ - getProductos()        │───┐       │
│ - createProducto()      │   │       │
│ - updateProducto()      │   └──────►│
│ - deleteProducto()      │           │
│ - searchProductos()     │           │
│ - refresh()             │           │
└─────────────────────────┘           │
                                      │
                            ┌─────────┴───────────┐
                            │   ApiService        │
                            ├─────────────────────┤
                            │ - _baseUrl: String  │
                            │ - _token: String    │
                            │                     │
                            │ Methods:            │
                            │ - getProductos()    │
                            │ - createProducto()  │
                            │ - updateProducto()  │
                            │ - deleteProducto()  │
                            │ - searchProductos() │
                            │ - setToken()        │
                            └─────────────────────┘
```

---

## 🧩 Componentes y Responsabilidades

### Config Layer
```dart
// env_config.dart
- baseUrl: Dirección del servidor
- baseUrlImg: Dirección de imágenes
- appName: Nombre de la aplicación
- appVersion: Versión de la aplicación
```

### Model Layer
```dart
// producto.dart
- Estructura de datos
- Conversión JSON ↔ Dart
- Validaciones de tipo

// login_response.dart
- Respuesta de autenticación
- Usuario logueado
```

### Service Layer
```dart
// api_service.dart
- Peticiones HTTP CRUD
- Manejo de headers
- Parseo de respuestas

// auth_service.dart
- Login/Logout
- Gestión de tokens
- Almacenamiento local
```

### Provider Layer
```dart
// auth_provider.dart
- Estado de autenticación
- Control de permisos
- Manejo de errores auth

// producto_provider.dart
- Lista de productos
- Estados de carga
- Mensajes de error
- Notificación de cambios
```

### View Layer
```dart
// splash_screen.dart
- Validación de sesión
- Navegación condicional

// login_screen.dart
- Formulario de login
- Validaciones de UI
- Manejo de errores

// productos_list_screen.dart
- Listado de productos
- Búsqueda
- Opciones CRUD
- Paginación

// producto_form_screen.dart
- Crear/Editar producto
- Validación de formulario
- Campos dinámicos
```

---

## ✨ Características Implementadas

- ✅ **Autenticación**: Login/Logout con JWT
- ✅ **Listado**: Productos con paginación
- ✅ **Búsqueda**: En tiempo real
- ✅ **Crear**: Nuevo producto
- ✅ **Editar**: Producto existente
- ✅ **Eliminar**: Producto con confirmación
- ✅ **Validaciones**: Cliente-side
- ✅ **Manejo de Errores**: Try-catch y UI feedback
- ✅ **State Management**: Provider
- ✅ **Persistencia**: SharedPreferences (token)
- ✅ **Tema**: Light/Dark automático
- ✅ **Loading States**: Indicadores de carga

---

## 🔐 Seguridad

1. **Token Storage**: SharedPreferences
2. **Authorization Header**: Incluido automáticamente
3. **Validación**: Cliente y servidor
4. **Logout**: Limpia datos locales
5. **Error Handling**: No expone detalles de servidor

---

## 📈 Escalabilidad

Estructura preparada para:
- Agregar más modelos
- Nuevas pantallas
- Caché local
- Sync offline
- Notificaciones push
- Análitica

---

## 🎯 Próximas Mejoras

```
Fase 2:
├─ Caché local con SQLite
├─ Sync offline
├─ Imágenes de productos
├─ Campos de precio/almacén
├─ Filtros avanzados
├─ Historial de cambios
└─ Reportes

Fase 3:
├─ Notificaciones push
├─ Biometría
├─ Múltiples idiomas
├─ Widgets del sistema
└─ App web (Flutter Web)
```

---

**Arquitectura lista y escalable 🚀**
