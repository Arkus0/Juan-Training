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

Registro de cambios (2026-01-25)
-------------------------------
- Añadido: `implementation("com.google.android.play:core:1.10.3")` en `android/app/build.gradle.kts` para proporcionar las clases de Play Core que R8 reportaba como faltantes durante la minificación. Esto resolvió el error de R8 y permitió completar el build release con minificación activada.
- Actualizado: `android/app/proguard-rules.pro` con reglas `-dontwarn com.google.android.play.core.*` para mitigar posibles warnings relacionados con Play Core cuando la dependencia no esté presente o no se use en runtime.

Notas:
- Si la app utiliza Delivery por características o Deferred Components, mantener la dependencia de Play Core es la opción correcta; de lo contrario, se puede revertir y depender solamente de las reglas `-dontwarn` si se prefiere no añadir esa dependencia en el árbol.
- Commit creado: "chore(android): add Play Core to satisfy R8; update ProGuard rules and docs"

