# 💪 Juan Training: La Biblioteca del Dolor

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev/)
[![Architecture](https://img.shields.io/badge/Architecture-Riverpod%20%2B%20Drift-purple)](https://riverpod.dev/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

> *"No pain, no gain. Pero sin datos, solo hay dolor sin gloria."*

Bienvenido a **Juan Training**, la herramienta definitiva para el culturista serio. Olvida las libretas sudadas y las apps genéricas de fitness que te cobran por respirar. Aquí venimos a levantar pesado, registrar cada gramo y construir un legado.

Esta es tu **Biblioteca del Dolor**. Una app offline-first, rápida como un rayo y sólida como el acero, diseñada para gestionar tus rutinas de hipertrofia y fuerza con precisión quirúrgica. Creada por y para entusiastas del hierro.

---

## 📸 La Sala de Trofeos (Screenshots)

*La interfaz visual donde se forjan las leyendas.*

| Pantalla Principal | Editor de Rutinas | Modo Entrenamiento |
|:---:|:---:|:---:|
| ![Dashboard](assets/screenshots/dashboard_placeholder.png) | ![Rutinas](assets/screenshots/rutinas_placeholder.png) | ![Entreno](assets/screenshots/workout_placeholder.png) |

*(Nota: Screenshots reales en proceso de definición muscular. Próximamente)*

---

## 🏆 Características de Campeón (Features)

Esta app no es para "tonificar". Es para progresar.

### 🏋️‍♂️ **Gestión de Rutinas "Old School"**
*   **Drag & Drop Táctico:** Reorganiza tus ejercicios y días arrastrando y soltando. Tan satisfactorio como cargar un disco de 20kg.
*   **Superseries Reales:** Agrupa ejercicios en superseries visuales. Se mueven juntos, se editan juntos. Sin líos de IDs.
*   **Duplicación de Días:** Copia tu "Leg Day" completo para la semana siguiente. Menos configuración, más hierro.
*   **Swipe-to-Dismiss con Undo:** ¿Te equivocaste borrando? Desliza para eliminar, pero con red de seguridad (Undo) por si el pre-entreno te jugó una mala pasada.
*   **Notas Detalladas:** Añade notas a tus ejercicios (setup del banco, altura del asiento) para no olvidar nunca tu configuración óptima.

### 🧠 **Entrenamiento Inteligente**
*   **Timer No Invasivo:** Barra de progreso discreta y avisos por vibración/sonido. Concéntrate en respirar, no en mirar el móvil.
*   **Ghost Values 👻:** Visualiza tus marcas de la sesión anterior (peso/reps) en gris claro justo donde escribes. Supera tu "yo" del pasado en cada serie.
*   **RPE & Tipos de Serie:** Registra RPE, Fallo, Calentamiento o Dropsets. Data real para un análisis real.
*   **Auto-Focus & Smart Input:** La app sabe dónde tienes que escribir. Flujo de trabajo optimizado para manos con magnesio.
*   **Inicio Smart:** La app sugiere automáticamente el día de rutina que toca hoy.

### 📚 **Biblioteca Masiva (Wger API)**
*   **700+ Ejercicios:** Base de datos completa, offline y con imágenes (thumbnails).
*   **Alternativas Biomecánicas:** ¿Máquina ocupada? La app te sugiere alternativas basadas en el mismo grupo muscular.
*   **Búsqueda Fuzzy:** Encuentra "Press de Banca" aunque escribas "banc pres".
*   **Favoritos:** Acceso rápido a tus movimientos "Signature".

### 📊 **Progresión y Datos**
*   **Historial de Sesiones:** Revisa tus entrenamientos pasados y compáralos con lo planeado.
*   **Progresión Lineal/Doble:** Herramientas integradas para asegurar la sobrecarga progresiva.
*   **Offline First:** Todo se guarda en tu dispositivo. No necesitas internet para entrenar en la cueva.

---

## ⚙️ Ingeniería Bajo el Capó

Construida con los mejores "esteroides" tecnológicos del ecosistema Flutter 2026.

*   **Flutter 3.x & Dart 3.x:** Última tecnología, null-safety total.
*   **Drift (SQLite):** Base de datos relacional robusta (migrada desde Hive). Soporta SQL complejo para consultas de historial y estadísticas.
*   **Riverpod:** Gestión de estado reactiva, testable y modular.
*   **Arquitectura Limpia:** Separación clara entre UI (`screens`), Lógica (`providers`) y Datos (`repositories`, `database`).

---

## 🚀 Instalación y Despliegue

¿Quieres compilar tu propia versión? Sigue estos pasos, recluta.

### Requisitos
*   Flutter SDK instalado (Canal Stable).
*   Un editor de código decente (VS Code / Android Studio).
*   Ganas de programar (y de entrenar).

### Pasos
1.  **Clona el repositorio:**
    ```bash
    git clone https://github.com/Arkus0/Juan-Training.git
    cd Juan-Training
    ```

2.  **Instala las dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Generación de Código (CRÍTICO):**
    Usamos `Drift` y `Riverpod Generator`. Debes correr el `build_runner` para generar los archivos `.g.dart` (modelos, base de datos, providers).
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Ejecuta la app:**
    ```bash
    flutter run
    ```

---

## 🗺️ Roadmap (El Camino al Mr. Olympia)

Aún nos queda camino para alcanzar la perfección física (y de software).

- [ ] 🎵 **Integración Spotify:** Controla tu playlist de "Heavy Metal Gym" sin salir de la app.
- [ ] 👁️ **OCR / Voz:** Importa rutinas de fotos o dicta tus series entre jadeos.
- [ ] 📈 **Gráficas Avanzadas:** Progresión de volumen, 1RM estimado y frecuencia por grupo muscular.
- [ ] ☁️ **Cloud Sync:** Backup en la nube y sincronización multiplataforma.
- [ ] 🌍 **Internacionalización:** Traducir la Biblioteca del Dolor a otros idiomas.

---

## 🤝 Únete al Equipo (Contribución)

Actualmente buscamos **Beta Testers** valientes.

Si encuentras un bug (que no sea un insecto real en tu gimnasio) o tienes una idea para una feature, **abre un Issue**. El código es open source, así que los Pull Requests son bienvenidos si siguen el estándar de calidad "Pro". ¡Ayúdanos a hacer la mejor app de culturismo del mundo!

---

## 📄 Licencia

Este proyecto está bajo la Licencia **MIT**. Eres libre de usarlo, modificarlo y aprender de él.

> *"Light weight, baby!"* — Ronnie Coleman (Patrón Espiritual del Proyecto)
