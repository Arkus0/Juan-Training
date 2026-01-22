# Juan Training App

![App Banner](assets/img/banner.png) *<!-- Si tienes un banner, sería genial ponerlo aquí -->*

Bienvenido a **Juan Training App**, la solución definitiva para gestionar tus entrenamientos de hipertrofia y fuerza. Diseñada para atletas que buscan precisión, flexibilidad y un control total sobre su progreso.

Más que una simple libreta digital, es tu **BIBLIOTECA DEL DOLOR**.

---

## 🚀 Funcionalidades Destacadas

### 🏋️‍♂️ **Gestión Inteligente de Rutinas**
*   **Editor Dinámico:** Crea y personaliza tus rutinas con facilidad. Arrastra y suelta para reordenar ejercicios o días completos.
*   **Soporte para Superseries:** Agrupa ejercicios visualmente en superseries. La interfaz las trata como bloques únicos para moverlas y gestionarlas sin caos.
*   **Duplicación de Días:** ¿Día de pierna similar al anterior? Duplica el día completo con un solo toque y ajusta lo necesario.
*   **Swipe-to-Dismiss con Undo:** Elimina ejercicios o rutinas deslizando, pero con la seguridad de poder deshacer la acción si te equivocas.

### 📚 **Biblioteca de Ejercicios Avanzada**
*   **Sincronización Inteligente:** Conexión directa con la API de Wger. Descarga miles de ejercicios, priorizando traducciones al español pero manteniendo el inglés como respaldo.
*   **Modo Offline Real:** Toda la biblioteca (incluidas imágenes) se descarga localmente. Entrena en el sótano o en la montaña sin preocuparte por la conexión.
*   **Filtros Potentes:** Busca por nombre, grupo muscular o equipamiento. Encuentra exactamente lo que necesitas en segundos.
*   **Favoritos:** Marca tus ejercicios clave para acceso rápido.

### ⏱️ **Sesiones de Entrenamiento Pro**
*   **Registro Preciso:** Anota peso, repeticiones y **RPE (Rate of Perceived Exertion)** para cada serie.
*   **Temporizador de Descanso:** Al terminar una serie, el temporizador se inicia automáticamente con el tiempo sugerido para ese ejercicio.
*   **Historial en Contexto (Ghost Values):** Visualiza lo que hiciste en la sesión anterior directamente en el campo de entrada. Toca para copiar y mejorar tu marca.
*   **Tipos de Serie:** Marca series como *Calentamiento*, *Fallo*, o *Dropset* para un análisis posterior detallado.

### 🔧 **Ingeniería Robusta**
*   **Base de Datos Drift (SQLite):** Migramos de Hive a Drift para ofrecer un rendimiento superior, consultas complejas y una integridad de datos a prueba de balas.
*   **Gestión de Estado con Riverpod:** Arquitectura reactiva y testable que asegura una experiencia de usuario fluida y sin errores.
*   **Haptic Feedback:** Respuesta táctil en cada interacción importante para que *sientas* la app mientras entrenas.

---

## 🛠️ Configuración para Desarrolladores

Si eres desarrollador y quieres contribuir o modificar la app, sigue estos pasos.

### Requisitos Previos
*   Flutter SDK (>=3.0.0 <4.0.0)
*   Dart SDK

### Pasos de Instalación

1.  **Clonar el repositorio:**
    ```bash
    git clone https://github.com/tu-usuario/juan-training.git
    cd juan-training
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Generar código (Drift & Riverpod):**
    Este proyecto utiliza generación de código para la base de datos y modelos. Es crucial ejecutar este comando antes de compilar.
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Ejecutar la aplicación:**
    ```bash
    flutter run
    ```

## 🏗️ Estructura del Proyecto

*   `lib/database/`: Definiciones de tablas y lógica de conexión de Drift.
*   `lib/models/`: Modelos de dominio y DTOs.
*   `lib/providers/`: StateNotifiers y Providers de Riverpod.
*   `lib/repositories/`: Capa de abstracción de datos (Patrón Repository).
*   `lib/screens/`: Pantallas de la UI organizadas por funcionalidad.
*   `lib/services/`: Lógica de negocio externa (ej. sincronización con API Wger).

## 🤝 Contribución

¡Las contribuciones son bienvenidas! Si tienes una idea para una nueva funcionalidad o encuentras un bug, abre un issue o envía un pull request.

---

Desarrollado con ❤️ y mucho café.
