plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ussdpay.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 18+ uses java.time.* internally, which
        // is only in java.time on API 26+. Desugaring backports it down to
        // our minSdk (24). See:
        // https://developer.android.com/studio/write/java8-support
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ussdpay.app"
        // Pinned rather than inherited: Flutter 3.44 dropped API 21-23, so 24 is the
        // real floor. Keep this explicit so a Flutter upgrade can't silently raise it.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backports java.time.* (and other Java 8+ APIs) to our minSdk 24, so
    // flutter_local_notifications can compile. Track pub.dev's plugin bump
    // notes if this version needs to change.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
