// Top-level build file where you can add configuration options common to all sub-projects/modules.
// Ini adalah file build.gradle.kts untuk root proyek Android Anda.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy {
            // Paksa penggunaan Kotlin Gradle Plugin versi 1.9.22 (sesuai dengan proyek Anda)
            // untuk semua modul, mengabaikan versi lama yang diminta oleh plugin.
            eachDependency {
                if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-gradle-plugin")) {
                    // Pastikan versi ini cocok dengan classpath Kotlin di 'buildscript' Anda (1.9.22)
                    useVersion("1.9.22")
                }
            }
        }
    }
    dependencies {
        // Deklarasikan versi Android Gradle Plugin (AGP) di sini.
        // Versi 8.2.2 sudah cukup untuk desugaring.
        classpath("com.android.tools.build:gradle:8.2.2")
        // Deklarasikan versi Kotlin Gradle Plugin (KGP) di sini.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
