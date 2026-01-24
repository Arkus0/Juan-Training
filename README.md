# 🏋️‍♂️ Juan Training: La Biblioteca del Dolor

> **"Enterprise-Grade Hypertrophy Management System."** — *Ronnie "The King" Coleman (CEO Espiritual)*

**Juan Training** no es otra aplicación de fitness genérica para contar pasos. Es una plataforma de ingeniería de software de alto rendimiento diseñada específicamente para la gestión de datos de hipertrofia y fuerza. Construida con una arquitectura robusta **Offline-First**, esta herramienta permite a los culturistas serios registrar, analizar y optimizar su progreso con precisión quirúrgica, eliminando la fricción entre el hierro y los datos.

Aquí no hay suscripciones, no hay anuncios y no hay excusas. Solo **Heavy Duty Software** para **Heavy Duty Training**.

---

## 🏆 Capacidades Operativas (Features)

Infraestructura desplegada y totalmente funcional en la versión actual `1.0.0+1`.

### 📚 **Base de Conocimiento (Exercise Library Core)**
*   **Arquitectura Híbrida:** Sincronización paralela (Español/Inglés) con la API Wger, procesada en `Isolates` de fondo para no bloquear la UI principal.
*   **Protección de Datos:** Sistema de IDs negativos para **Ejercicios Personalizados** y lógica de "Curated Protection" que impide que la sincronización sobrescriba tus datos manuales.
*   **Cache Inteligente:** Gestión automática de imágenes offline con herramientas de saneamiento (eliminación de archivos de 0 bytes) y limpieza manual desde ajustes.

### 🧠 **Ingesta de Datos Inteligente (Smart Input)**
*   **Reconocimiento Óptico (OCR) on-device:** Implementación de **Google ML Kit** para escanear rutinas escritas en pizarras o papel. Detecta series, repeticiones y pesos automáticamente.
*   **Comandos de Voz (Voice Ops):** Sistema de dictado natural ("Añade sentadilla 4 por 10") procesado localmente con feedback de audio. Entrena sin tocar la pantalla.
*   **Numpad Modal Táctico:** Modo de entrada optimizado para dedos con magnesio. Botones grandes, sin teclado del sistema.

### ⚙️ **Gestión de Rutinas & Superseries**
*   **Arquitectura de Superseries Atómicas:** Agrupación visual y lógica de ejercicios. Se mueven, editan y ejecutan como una unidad indivisible.
*   **Edición No Destructiva:** Funcionalidad "Undo" global y sistema "Swipe-to-Dismiss" con red de seguridad.
*   **Duplicación de Días:** Clonación profunda de estructuras de entrenamiento para iteración rápida de microciclos.

### ⚡ **Modo Entrenamiento (Workout Execution)**
*   **Timer Híbrido (Android Exclusive):** Servicio en primer plano (`Foreground Service`) que mantiene el temporizador de descanso visible y funcional incluso en la pantalla de bloqueo.
*   **Calculadora de Platos:** Herramienta visual integrada para saber exactamente qué discos cargar en la barra. No más matemáticas mentales bajo fatiga.
*   **Control Multimedia Táctico (Android Exclusive):** Interfaz nativa (Kotlin bridge) para controlar Spotify/Música sin salir de la sesión de entrenamiento.
*   **Ghost Values:** Proyección de datos históricos (peso/reps anteriores) directamente en los campos de entrada para facilitar la sobrecarga progresiva (Progressive Overload).

### 🔧 **Configuración del Sistema (Settings)**
*   **Performance Mode:** Opción para desactivar animaciones costosas y vibraciones en dispositivos de gama baja. Prioridad al rendimiento puro.
*   **Guías Interactivas:** Documentación integrada dentro de la app que explica el funcionamiento del OCR, Voz y Progresión Automática.
*   **Gestión de Almacenamiento:** Monitorización en tiempo real del uso de disco (imágenes/JSON) con herramientas de limpieza one-tap.

### 📊 **Analítica Avanzada (Analysis Lab)**
*   **Centro de Comando (AnalysisScreen):** Dashboard unificado que reemplaza al historial lineal tradicional.
*   **Métricas de Rendimiento:**
    *   **Activity Heatmap:** Visualización de consistencia estilo GitHub.
    *   **Symmetry Radar:** Análisis de balance muscular.
    *   **Recovery Monitor:** Estimación de fatiga sistémica.
    *   **Hall of Fame:** Registro automático de PRs (Personal Records) históricos.

---

## 🏗️ Stack Tecnológico (The Tech Stack)

Construido sobre cimientos sólidos. "Light weight framework, heavy weight performance."

*   **Core:** Flutter 3.x & Dart 3.x (Null Safety).
*   **Estado:** `flutter_riverpod` v2 (Gestión reactiva y testable).
*   **Persistencia:** `drift` (SQLite) con `sqlite3_flutter_libs`. Base de datos relacional para consultas complejas de análisis.
*   **Machine Learning:** `google_mlkit_text_recognition` (Versión 'thin' con descarga dinámica de modelos).
*   **Speech:** `speech_to_text` (Motores nativos offline).
*   **Nativo (Android):** Código Kotlin para `MediaSessionManager` y `ForegroundServices`.

---

## 📋 Requisitos del Sistema

Para desplegar este entorno de desarrollo necesitarás:

*   **Flutter SDK:** Canal Stable (versión >= 3.0.0).
*   **Dart SDK:** Compatible (versión >= 3.0.0).
*   **Entorno Android:** Android SDK actualizado (para compilar las features nativas).
*   **Dispositivo Físico:** Recomendado para probar OCR, Voz y Vibración (los emuladores carecen de hardware de cámara/micrófono fiel).

---

## 🚀 Protocolo de Instalación

Sigue estos pasos estrictos. No te saltes el día de pierna, no te saltes el `build_runner`.

1.  **Clonar el Repositorio:**
    ```bash
    git clone <repository_url>
    cd juan_training
    ```

2.  **Instalar Dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Generación de Código (CRÍTICO):**
    Este proyecto utiliza metaprogramación intensiva para Drift (BBDD) y Riverpod (Providers). Debes compilar los generadores antes de ejecutar.
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Ejecución:**
    ```bash
    flutter run
    ```

---

## 📂 Estructura del Proyecto

Organización modular para escalabilidad empresarial.

```text
lib/
├── database/       # Definiciones de esquemas Drift y DAOs.
├── models/         # Modelos de dominio (Rutina, Sesion, Ejercicio).
├── providers/      # Lógica de negocio y gestión de estado (Riverpod).
├── repositories/   # Capa de abstracción de datos.
├── screens/        # Interfaces de usuario (UI).
│   ├── analysis/   # Dashboards y gráficas.
│   ├── settings/   # Configuración y guías del sistema.
│   └── ...
├── services/       # Lógica externa (OCR, Voz, Audio, Validaciones).
├── utils/          # Design System, formateadores y helpers.
├── widgets/        # Componentes reutilizables atómicos.
└── main.dart       # Punto de entrada y configuración global.
```

---

## ⚠️ Notas de Despliegue

*   **Permisos Android:** El `AndroidManifest.xml` está configurado para solicitar permisos de **Cámara** (OCR), **Micrófono** (Voz), **Notificaciones** (Timer) y **Overlay** (Servicios).
*   **Modelos ML:** La app está configurada para descargar el modelo de OCR vía Google Play Services la primera vez que se usa, manteniendo el APK ligero.
*   **Plataformas:** Aunque el core es Flutter (multiplataforma), las funcionalidades de **Timer en Pantalla de Bloqueo** y **Control de Medios** tienen implementaciones nativas específicas en `android/app/src/main/kotlin`. En iOS estas features pueden tener comportamiento limitado.

---

## 🤝 Contribución (Join the Crew)

Buscamos desarrolladores que levanten código tan pesado como sus sentadillas.

Si encuentras un bug o quieres optimizar una query SQL, abre un **Pull Request**. El estándar de calidad es alto: código limpio, tipado estricto y respeto por la arquitectura Riverpod/Drift.

> *"Todo el mundo quiere ser un bodybuilder, pero nadie quiere levantar pesos pesados... ni escribir tests unitarios."*
