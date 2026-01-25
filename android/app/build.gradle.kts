plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.juan_training"
    // Set concrete compileSdk to satisfy newer AAR metadata (many libraries require >= 34).
    // Use 36 to be safe and match Flutter's targetSdk.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.juan_training"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Excluir recursos de debug y optimizar
        ndk {
            // Solo incluir ABIs necesarios para dispositivos modernos
            // arm64-v8a: dispositivos ARM 64-bit (mayoría de dispositivos modernos)
            // armeabi-v7a: dispositivos ARM 32-bit (dispositivos más antiguos)
            // x86_64: emuladores (opcional, se puede omitir para release)
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // 🎯 ABI Splits: Genera APKs separados por arquitectura
    // Reduce el tamaño de ~400MB (fat APK) a ~80-120MB por arquitectura
    splits {
        abi {
            isEnable = true
            reset()
            // Incluir solo arquitecturas ARM (la mayoría de dispositivos reales)
            include("arm64-v8a", "armeabi-v7a")
            // Excluir x86/x86_64 (solo emuladores) - reduce ~50MB
            isUniversalApk = false // No generar APK universal (usa AAB para distribución)
        }
    }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AndroidX Media for MediaStyle notifications and MediaSession compat
    implementation("androidx.media:media:1.7.0")

    // Play Core (SplitInstall / SplitCompat) — ensure classes referenced by Flutter's
    // deferred components are available to R8. Update version if needed.
    implementation("com.google.android.play:core:1.10.3")
}

    buildTypes {
        release {
            // TODO: Añadir tu propia signing config para release.
            // Por ahora firmamos con debug para que `flutter run --release` funcione.
            signingConfig = signingConfigs.getByName("debug")

            // -----------------------------------------------------------------
            // Reactivando minificación (temporal) para validar si las reglas
            // ProGuard mitigaron los errores de R8. Si falla, revertir y
            // seguir la "solución completa" (añadir módulos ML Kit).
            // -----------------------------------------------------------------
            isMinifyEnabled = true
            isShrinkResources = true

            // Reglas ProGuard específicas para mitigar referencias faltantes.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
