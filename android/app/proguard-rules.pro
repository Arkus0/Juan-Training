# Reglas de ProGuard / R8 para la app
# Añadir -keep o -dontwarn según se necesite cuando se active minificación.

# Mantener las clases ML Kit que puedan usarse (ajustar según los módulos concretos)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Mantener las clases usadas por plugins de Flutter (ejemplos comunes)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Suppress warnings for Play Core (deferred components / split install) when Play Core
# is not explicitly added as a dependency.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Si se usan reflection/`fromToken` style calls, añadir reglas -keep específicas para las
# clases o métodos que se invocan por reflexión. Evitar reglas genéricas que puedan romper la
# sintaxis de ProGuard/R8; añadir aquí los -keep concretos cuando se identifiquen.
