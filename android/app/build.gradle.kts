plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.medimate_practice"
    compileSdk = 34 //flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" //flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true //Untuk menjalankan flutter notifications
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.medimate_practice"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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