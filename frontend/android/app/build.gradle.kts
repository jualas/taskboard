plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cifpcarlos3.tfg.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Actualizado para compatibilidad con plugins

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.cifpcarlos3.tfg.frontend"
        // Configuración específica para el proyecto TFG
        minSdk = 21 // Android 5.0 (API level 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0.0"
        
        // Configuración para múltiples idiomas
        resConfigs("es", "en")
        
        // Configuración de rendimiento
        multiDexEnabled = true
    }

    buildTypes {
        debug {
            // Configuración para desarrollo
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
        
        release {
            // Configuración para producción
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // Configuración para diferentes densidades de pantalla
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }

    // Renombrar el archivo APK de salida
    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val abi = output.getFilter(com.android.build.OutputFile.ABI)
                if (abi != null) {
                    output.outputFileName = "SistemaTFG_v${variant.versionName}_$abi.apk"
                } else {
                    output.outputFileName = "SistemaTFG_v${variant.versionName}.apk"
                }
            }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Soporte para múltiples DEX files
    implementation("androidx.multidex:multidex:2.0.1")
}
