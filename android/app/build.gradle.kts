plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.medimate" // Pastikan ini sesuai dengan package aplikasi Anda
    compileSdk = 34 // flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Versi NDK yang dibutuhkan

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11 // Diperlukan untuk desugaring
        targetCompatibility = JavaVersion.VERSION_11 // Diperlukan untuk desugaring
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() // Tetap Java 11 untuk Kotlin
    }

    buildFeatures {
        // Disable Play Store deferred components
        // This tells Flutter not to use SplitCompat or PlayCore
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.example.medimate" // ID aplikasi Anda
        minSdk = 21 //flutter.minSdkVersion
        targetSdk = 34 //flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // isCoreLibraryDesugaringEnabled = true // <-- Sekarang ini akan dikenali
        manifestPlaceholders["flutterEmbedding"] = "2"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
            // isDebuggable = true // optional: bisa lihat log lebih jelas di build release
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

dependencies {
    // Tambahkan dependensi desugaring di sini
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    
    // Tambahkan dependensi lain yang mungkin Anda miliki di sini
    // Contoh:
    implementation("androidx.multidex:multidex:2.0.1")
    // implementation("androidx.core:core-ktx:1.10.1")
}