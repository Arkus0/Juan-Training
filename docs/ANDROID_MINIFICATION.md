Android minification / R8 — notas y pasos para reactivar (documentación)

Resumen
-------
Se ha desactivado temporalmente la minificación (`isMinifyEnabled = false`) y la reducción de recursos
(`isShrinkResources = false`) en `android/app/build.gradle.kts` debido a errores de R8 durante el
proceso de build release: faltaban clases de ML Kit (por ejemplo `ChineseTextRecognizerOptions`) que
provocaban fallos en la fase de minificación.

¿Por qué ocurrió?
------------------
Algunas dependencias transitivas (p. ej. el plugin `google_mlkit_text_recognition`) pueden asumir la
presencia de módulos ML Kit específicos para idiomas (chino, japonés, coreano, devanagari, ...).
Si esos artefactos no están presentes ni se configuraron adecuadamente, R8 puede fallar al procesar
la cadena de clases.

Opciones para reactivar minificación (recomendadas)
---------------------------------------------------
1) "La solución completa" (recomendada si usas ML Kit):
   - Añadir explícitamente los módulos ML Kit que usas en `android/app/build.gradle.kts`, por ejemplo:
     implementation("com.google.mlkit:vision-text-chinese:<version>")
     implementation("com.google.mlkit:vision-text-japanese:<version>")
     (Usa las versiones compatibles con los plugins instalados; consulta la documentación del plugin.)
   - Activar `isMinifyEnabled = true` y `isShrinkResources = true` y ejecutar `flutter build apk`.
   - Si aparecen warnings de R8, ajustar `proguard-rules.pro` para mantener clases necesarias o evitar
     que se eliminen símbolos referenciados por reflexión.

2) "Solución rápida" (si no necesitas esos módulos ahora):
   - Mantener minificación desactivada (como ahora) y documentar en este repositorio (archivo actual).
   - Añadir reglas en `proguard-rules.pro` (ya existe en `android/app/`) con reglas -dontwarn y -keep
     para `com.google.mlkit.**` como mitigación cuando se reabilite minificación.

Archivos relevantes
-------------------
- `android/app/build.gradle.kts`  -> buildTypes.release tiene minificación desactivada y referencia a `proguard-rules.pro`.
- `android/app/proguard-rules.pro` -> Reglas iniciales de ProGuard/R8 (añadir/ajustar según necesidades).

Pasos sugeridos para reactivar (checklist)
-----------------------------------------
- [ ] Determinar qué módulos ML Kit necesita realmente la app (o los plugins que usa).
- [ ] Añadir las dependencias ML Kit necesarias en `android/app/build.gradle.kts`.
- [ ] Habilitar minificación y shrinking.
- [ ] Ejecutar build; si hay errores de R8, inspeccionarlos y añadir reglas -keep/-dontwarn necesarias.
- [ ] (Opcional) Ejecutar `flutter build apk --release -v` para ver logs detallados si falla.

Contacto
--------
Si quieres, puedo:
- Probar a añadir los módulos ML Kit que parecen faltar (lista de módulos detectados en log: chinese, devanagari, japanese, korean) y volver a activar minificación, o
- Simplemente dejar la configuración como está y documentarla (lo que hemos hecho ahora).

