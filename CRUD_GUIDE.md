# 📱 CRUD de Productos - Guía Completa

## 🏗️ Estructura del Proyecto (Arquitectura 3 Capas)

```
lib/
├── config/
│   └── env_config.dart              ⚙️ Configuración del ambiente
├── models/
│   ├── producto.dart                📦 Modelo de Producto
│   └── login_response.dart          🔐 Modelo de Login
├── services/                         🌐 Servicios (Capa de Datos)
│   ├── api_service.dart             API de Productos
│   └── auth_service.dart            API de Autenticación
├── providers/                        📊 Estado (Capa de Lógica)
│   ├── auth_provider.dart           Gestión de Autenticación
│   └── producto_provider.dart       Gestión de Productos
├── views/                            🎨 Vistas (Capa de Presentación)
│   ├── splash_screen.dart           Pantalla de inicio
│   ├── login_screen.dart            Pantalla de login
│   ├── productos_list_screen.dart   Listado de productos
│   └── producto_form_screen.dart    Crear/Editar producto
└── main.dart                         🚀 Punto de entrada
```

---

## 🔧 Configuración Inicial

### 1. Instalar dependencias
```bash
flutter pub get
```

### 2. Dependencias requeridas (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.1.0              # Peticiones HTTP
  provider: ^6.1.0          # State management
  shared_preferences: ^2.2.2 # Almacenar token
  flutter_dotenv: ^5.1.0    # Variables de entorno
  intl: ^0.19.0             # Internacionalización
```

### 3. Configurar conexión
En `lib/config/env_config.dart`:
```dart
static const String baseUrl = 'http://192.168.100.42:8000/api';
```

---

## 📐 Arquitectura MVC (3 Capas)

### 🌐 **Capa 1: Services (Datos)**
Comunicación con la API

#### `auth_service.dart`
```dart
Future<LoginResponse> login(String email, String password)
Future<void> logout()
Future<LoginResponse> register(...)
Future<String?> getToken()
Future<bool> isAuthenticated()
```

#### `api_service.dart`
```dart
Future<List<Producto>> getProductos()
Future<Producto> getProductoById(int id)
Future<Producto> createProducto(Producto producto)
Future<Producto> updateProducto(int id, Producto producto)
Future<void> deleteProducto(int id)
Future<List<Producto>> searchProductos(String query)
```

---

### 📊 **Capa 2: Providers (Lógica de Negocio)**
Gestión de estado con Provider

#### `auth_provider.dart`
```dart
bool isAuthenticated      // ¿Está autenticado?
bool isLoading           // ¿Está cargando?
String? errorMessage     // Mensaje de error
Map<String, dynamic>? user // Datos del usuario

Future<bool> login(email, password)
Future<void> logout()
Future<bool> register(name, email, password, ...)
void clearError()
```

#### `producto_provider.dart`
```dart
List<Producto> productos     // Lista de productos
bool isLoading              // ¿Está cargando?
String? errorMessage        // Mensaje de error

Future<void> getProductos({int page = 1})
Future<void> loadMoreProductos()
Future<bool> createProducto(Producto)
Future<bool> updateProducto(int id, Producto)
Future<bool> deleteProducto(int id)
Future<void> searchProductos(String query)
Future<void> refresh()
```

---

### 🎨 **Capa 3: Views (Presentación)**
Interfaces de usuario

#### `splash_screen.dart`
- Pantalla de carga inicial
- Verifica autenticación
- Redirige a login o lista de productos

#### `login_screen.dart`
- Formulario de login
- Validación de credenciales
- Manejo de errores

#### `productos_list_screen.dart`
- Listado de productos
- Búsqueda en tiempo real
- Opciones de editar/eliminar
- Botón flotante para crear
- Paginación

#### `producto_form_screen.dart`
- Crear nuevo producto
- Editar producto existente
- Validación de campos
- Checkboxes para opciones booleanas

---

## 🚀 Flujos de Uso

### 🔐 Flujo de Login
```
1. Usuario abre app → SplashScreen
2. SplashScreen verifica autenticación
3. ❌ No autenticado → LoginScreen
4. Usuario ingresa email y contraseña
5. AuthProvider.login() → AuthService.login()
6. ✅ Token guardado en SharedPreferences
7. Redirige a ProductosListScreen
```

### 📦 Flujo de Listar Productos
```
1. ProductosListScreen cargada
2. ProductoProvider.getProductos()
3. ApiService.getProductos() → GET /api/productos
4. Respuesta JSON → parseada a List<Producto>
5. Actualiza estado con notifyListeners()
6. UI renderiza ListView
```

### ➕ Flujo de Crear Producto
```
1. Usuario click botón flotante "+"
2. Navega a ProductoFormScreen(producto: null)
3. Usuario rellena formulario
4. Click botón "Crear"
5. Valida nombre (requerido)
6. ProductoProvider.createProducto() → ApiService.createProducto()
7. POST /api/productos con datos
8. ✅ Producto creado → actualiza lista
9. Muestra SnackBar de éxito
10. Regresa a ProductosListScreen
```

### ✏️ Flujo de Editar Producto
```
1. Usuario click en producto o en opción "Editar"
2. Navega a ProductoFormScreen(producto: producto)
3. Formulario pre-llena con datos del producto
4. Usuario modifica campos
5. Click botón "Actualizar"
6. ProductoProvider.updateProducto() → ApiService.updateProducto()
7. PUT /api/productos/{id} con datos
8. ✅ Producto actualizado → actualiza lista
9. Muestra SnackBar de éxito
10. Regresa a ProductosListScreen
```

### 🗑️ Flujo de Eliminar Producto
```
1. Usuario abre popup de opciones
2. Click "Eliminar"
3. Mostrar dialog de confirmación
4. Usuario confirma
5. ProductoProvider.deleteProducto() → ApiService.deleteProducto()
6. DELETE /api/productos/{id}
7. ✅ Producto eliminado de lista local
8. Muestra SnackBar de éxito
```

---

## 🔄 Integración con Backend

### Endpoints utilizados
```
POST   /api/login              Login
POST   /api/logout             Logout
POST   /api/register           Registro

GET    /api/productos          Listar productos (paginado)
GET    /api/productos/:id      Obtener un producto
POST   /api/productos          Crear producto
PUT    /api/productos/:id      Actualizar producto
DELETE /api/productos/:id      Eliminar producto
GET    /api/productos?q=...    Buscar productos
```

### Headers
```dart
{
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'Authorization': 'Bearer {token}'  // Incluido automáticamente
}
```

### Respuesta esperada de login
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "name": "Usuario",
    "email": "usuario@example.com"
  }
}
```

### Respuesta esperada de productos
```json
{
  "data": [
    {
      "id": 1,
      "nombre": "Producto A",
      "sku": "SKU001",
      "descripcion": "Descripción...",
      "peso": 1.5,
      "stock_minimo": 10,
      "stock_maximo": 100,
      "activo": true,
      "visible_app": true,
      ...
    }
  ]
}
```

---

## 🎯 Casos de Uso

### ✅ Crear Producto
```dart
final producto = Producto(
  id: 0,
  nombre: 'Laptop',
  sku: 'LAP001',
  descripcion: 'Laptop de 15 pulgadas',
  peso: 2.5,
  stockMinimo: 5,
  stockMaximo: 50,
  activo: true,
);

await context.read<ProductoProvider>().createProducto(producto);
```

### ✅ Actualizar Producto
```dart
await context.read<ProductoProvider>().updateProducto(
  producto.id,
  productoModificado,
);
```

### ✅ Eliminar Producto
```dart
await context.read<ProductoProvider>().deleteProducto(productoId);
```

### ✅ Buscar Productos
```dart
await context.read<ProductoProvider>().searchProductos('laptop');
```

### ✅ Logout
```dart
await context.read<AuthProvider>().logout();
```

---

## 🛡️ Manejo de Errores

### En Services
```dart
try {
  // Petición a API
} catch (e) {
  throw Exception('Error: $e');
}
```

### En Providers
```dart
try {
  final resultado = await _apiService.getProductos();
  _productos = resultado;
} catch (e) {
  _errorMessage = e.toString().replaceFirst('Exception: ', '');
}
notifyListeners();
```

### En Vistas
```dart
if (provider.errorMessage != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(provider.errorMessage!))
  );
}
```

---

## 🔐 Almacenamiento Local

Token almacenado con **SharedPreferences**:
```dart
// Guardar
await prefs.setString('auth_token', token);

// Recuperar
final token = prefs.getString('auth_token');

// Limpiar
await prefs.remove('auth_token');
```

---

## 📱 Flujo de Navegación

```
SplashScreen (2 segundos)
    ↓
¿Autenticado?
    ├─ NO  → LoginScreen → ProductosListScreen
    └─ SÍ → ProductosListScreen

ProductosListScreen
    ├─ Nuevo (+)         → ProductoFormScreen (crear)
    ├─ Click producto    → ProductoFormScreen (editar)
    ├─ Editar            → ProductoFormScreen (editar)
    ├─ Eliminar          → Confirmación → Elimina
    ├─ Buscar            → Filter en tiempo real
    └─ Cerrar sesión     → LoginScreen
```

---

## 🧪 Testing

### Credenciales de prueba (ajusta según tu backend)
```
Email:    usuario@example.com
Password: password123
```

### Pruebas manuales
- [ ] Login con credenciales inválidas
- [ ] Login con credenciales válidas
- [ ] Listar productos vacío
- [ ] Listar productos con datos
- [ ] Crear producto sin nombre (debe fallar)
- [ ] Crear producto con datos válidos
- [ ] Editar producto existente
- [ ] Eliminar producto
- [ ] Buscar productos
- [ ] Logout
- [ ] Paginación

---

## 📝 Notas Importantes

1. **Token**: Se almacena automáticamente al login en SharedPreferences
2. **Autorización**: El token se incluye automáticamente en todos los requests
3. **Estado**: El estado se mantiene mientras la app esté en memoria
4. **Paginación**: Carga 12 productos por página
5. **Búsqueda**: Es en tiempo real al escribir
6. **Validaciones**: Se hacen en el frontend antes de enviar

---

## 🚀 Próximos Pasos

- [ ] Agregar validaciones más robustas
- [ ] Implementar cache local
- [ ] Agregar soporte offline
- [ ] Mejorar manejo de errores de red
- [ ] Agregar refresh pull-to-refresh
- [ ] Implementar filtros avanzados
- [ ] Agregar campos de precios y almacenes
- [ ] Implementar imágenes de productos

---

**¡Listo para usar! 🎉**
