# Juan Training App

Aplicación de rutinas personalizadas construida con Flutter y Hive.

## Configuración Inicial

Este proyecto utiliza Hive con generación de código para los adaptadores de tipo (`TypeAdapter`). Antes de ejecutar la aplicación, debes generar estos archivos.

### Pasos:

1.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

2.  **Generar adaptadores de Hive:**
    Ejecuta el siguiente comando en la terminal para generar los archivos `.g.dart` necesarios (ej. `ejercicio.g.dart`, `rutina.g.dart`):
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

3.  **Ejecutar la app:**
    ```bash
    flutter run
    ```

## Estructura del Proyecto

-   `lib/models/`: Modelos de datos (Rutina, Ejercicio, Sesion) con anotaciones Hive.
-   `lib/screens/`: Pantallas de la aplicación (Main, Rutinas, Crear/Editar).
-   `lib/main.dart`: Punto de entrada, inicialización de Hive y configuración de rutas.

## Funcionalidades

-   **Rutinas**: Ver lista de rutinas guardadas.
-   **Crear/Editar Rutina**: Formulario dinámico para añadir ejercicios, series, repeticiones y pesos.
-   **Persistencia**: Todo se guarda localmente usando Hive.
