# ⚙️ Configuración de Ambientes - Flutter App

## 🎯 La Fuente de Verdad es `.env`

El archivo `.env` es la **fuente única de verdad** para toda la configuración de la aplicación. Todos los valores se cargan desde aquí en tiempo de ejecución.

---

## 📁 Estructura de Configuración

```
app_inventario/
├── .env                    ← FUENTE DE VERDAD
├── .env.example            ← Template para nuevos desarrolladores
├── .env.staging            ← (Opcional) Configuración staging
├── .env.production         ← (Opcional) Configuración producción
└── lib/
    └── config/
        └── env_config.dart ← Lee desde .env (NO hardcodear valores)
```

---

## 🔄 Cómo Funciona

### 1️⃣ **Al iniciar la app**
```dart
// main.dart
Future<void> main() async {
  await dotenv.load(fileName: '.env');  // ← Lee .env
  EnvConfig.printConfig();              // ← Muestra configuración
  runApp(const MyApp());
}
```

### 2️⃣ **Acceder a valores**
```dart
// En cualquier parte de la app
String baseUrl = EnvConfig.baseUrl;    // Lee desde .env
bool debug = EnvConfig.appDebug;       // Lee desde .env
```

### 3️⃣ **NO hardcodear valores**
```dart
// ❌ MAL - Hardcodeado
static const String baseUrl = 'http://192.168.100.42:8000/api';

// ✅ BIEN - Lee desde .env
static String get baseUrl => dotenv.env['BASE_URL'] ?? 'fallback';
```

---

## 📝 Variables disponibles en `.env`

```env
# Aplicación
APP_NAME=Distribuidora Paucara
APP_VERSION=1.0.0
APP_DEBUG=true

# URLs del servidor
BASE_URL_WEB=http://192.168.100.42:8000
BASE_URL=http://192.168.100.42:8000/api
BASE_URL_IMG=http://192.168.100.42:8000/storage/

# Configuración de API
API_TIMEOUT=30
API_RETRY_COUNT=3

# Almacenamiento
STORAGE_PATH=products
CACHE_ENABLED=true
CACHE_DURATION=3600
```

---

## 🔀 Cambiar entre Ambientes

### Opción 1: Editar `.env` directamente

Para **cambiar de servidor**, edita el archivo `.env`:

```env
# DESARROLLO (Local)
BASE_URL=http://192.168.100.42:8000/api
BASE_URL_IMG=http://192.168.100.42:8000/storage/
APP_DEBUG=true

# PRODUCCIÓN (Descomenta para usar)
# BASE_URL=https://paucara.up.railway.app/api
# BASE_URL_IMG=https://paucara.up.railway.app/storage/
# APP_DEBUG=false
```

Luego ejecuta:
```bash
flutter clean
flutter pub get
flutter run
```

---

### Opción 2: Crear archivos separados (Recomendado)

```bash
# Crear archivos por ambiente
.env.development    ← Local (16MB, 8000)
.env.staging        ← Staging (Railway)
.env.production     ← Production (Railway)
```

Luego crea un script para cambiar:

```bash
#!/bin/bash
# switch_env.sh

if [ "$1" == "dev" ]; then
  cp .env.development .env
  echo "✅ Ambiente: DESARROLLO"
elif [ "$1" == "staging" ]; then
  cp .env.staging .env
  echo "✅ Ambiente: STAGING"
elif [ "$1" == "prod" ]; then
  cp .env.production .env
  echo "✅ Ambiente: PRODUCCIÓN"
else
  echo "Uso: ./switch_env.sh [dev|staging|prod]"
fi

flutter clean && flutter pub get
```

Usar:
```bash
./switch_env.sh dev       # Cambiar a desarrollo
./switch_env.sh prod      # Cambiar a producción
```

---

## 🚀 Ejemplo: Cambiar de Servidor

### Local → Producción

**Archivo `.env` Actual (Local):**
```env
BASE_URL=http://192.168.100.42:8000/api
BASE_URL_IMG=http://192.168.100.42:8000/storage/
APP_DEBUG=true
```

**Cambiar a Producción:**
```env
BASE_URL=https://paucara.up.railway.app/api
BASE_URL_IMG=https://paucara.up.railway.app/storage/
APP_DEBUG=false
```

**Recargar app:**
```bash
flutter clean
flutter run
```

---

## 📊 Acceder a la Configuración en el Código

```dart
import 'package:app_inventario/config/env_config.dart';

// En cualquier lugar de la app
class MyService {
  final String baseUrl = EnvConfig.baseUrl;
  final String imageUrl = EnvConfig.baseUrlImg;
  final int timeout = EnvConfig.apiTimeout;
  final bool debug = EnvConfig.appDebug;
  
  void printCurrentConfig() {
    EnvConfig.printConfig();  // Mostrar configuración actual
  }
}
```

---

## 🔍 Verificar Configuración Cargada

Al ejecutar la app, verás en la consola:

```
════════════════════════════════════════
⚙️  CONFIGURACIÓN CARGADA DEL .env
════════════════════════════════════════
📱 App: Distribuidora Paucara v1.0.0
🌐 Base URL: http://192.168.100.42:8000/api
📸 Images URL: http://192.168.100.42:8000/storage/
⏱️  Timeout: 30s
🔄 Retry: 3 intentos
💾 Cache: Habilitado
════════════════════════════════════════
```

---

## 🚫 NO Hacer

```dart
// ❌ NUNCA hardcodear URLs
class ApiService {
  static const String baseUrl = 'http://192.168.100.42:8000/api';  // ❌ MAL
}

// ❌ NUNCA copiar valores
final url = 'http://192.168.100.42:8000/api';  // ❌ MAL

// ❌ NUNCA ignorar .env
// Si lo haces, tendrás que compilar de nuevo para cambiar servidor
```

---

## ✅ BIEN Hacer

```dart
// ✅ SIEMPRE usar EnvConfig
class ApiService {
  final String baseUrl = EnvConfig.baseUrl;  // ✅ BIEN
}

// ✅ SIEMPRE centralizar en EnvConfig
// Una sola fuente de verdad

// ✅ SIEMPRE cambiar en .env
// Solo edita .env, nunca el código
```

---

## 📋 Checklist para Cambiar Ambiente

```
□ Editar archivo .env con nuevas URLs
□ Descomenta/comenta líneas según ambiente
□ Ejecutar: flutter clean
□ Ejecutar: flutter pub get
□ Ejecutar: flutter run
□ Verificar logs de EnvConfig
□ Probar login en nuevo servidor
```

---

## 🔐 Produccción Checklist

```
□ APP_DEBUG=false
□ BASE_URL=https://paucara.up.railway.app/api
□ BASE_URL_IMG=https://paucara.up.railway.app/storage/
□ API_TIMEOUT=60 (aumentar para conexiones lentas)
□ CACHE_ENABLED=true
□ Compilar APK/IPA final
□ Probar en dispositivo real
```

---

## 🌐 Ejemplo: Tres Ambientes

### `.env.development`
```env
APP_NAME=Distribuidora Paucara (DEV)
APP_DEBUG=true
BASE_URL=http://192.168.100.42:8000/api
BASE_URL_IMG=http://192.168.100.42:8000/storage/
API_TIMEOUT=30
```

### `.env.staging`
```env
APP_NAME=Distribuidora Paucara (STAGING)
APP_DEBUG=true
BASE_URL=https://staging-paucara.railway.app/api
BASE_URL_IMG=https://staging-paucara.railway.app/storage/
API_TIMEOUT=45
```

### `.env.production`
```env
APP_NAME=Distribuidora Paucara
APP_DEBUG=false
BASE_URL=https://paucara.up.railway.app/api
BASE_URL_IMG=https://paucara.up.railway.app/storage/
API_TIMEOUT=60
CACHE_ENABLED=true
```

---

## 📚 Dependencia Usada

```yaml
flutter_dotenv: ^5.1.0
```

**Características:**
- ✅ Lee archivos `.env`
- ✅ Carga en tiempo de ejecución
- ✅ No requiere recompilación
- ✅ Seguro para variables sensibles
- ✅ Soporta comentarios (#)

---

## 🎯 Resumen

| Aspecto | Detalles |
|--------|----------|
| **Fuente de Verdad** | `.env` |
| **Acceso** | `EnvConfig.baseUrl`, etc. |
| **Cambiar** | Editar `.env` + `flutter clean` |
| **Hardcodear URLs** | ❌ NUNCA |
| **Ambiente** | Se controla 100% desde `.env` |

---

## 🚀 Listo

Ahora puedes cambiar entre ambientes **sin compilar de nuevo** solo editando el `.env` y ejecutando `flutter clean && flutter run`.

**¡Tu app es totalmente configurable! 🎉**
