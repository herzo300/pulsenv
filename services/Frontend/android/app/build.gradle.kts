import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.soobshio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("keystore.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { stream ->
            keystoreProperties.load(stream)
        }
    }
    val releaseStoreFile =
        (keystoreProperties.getProperty("storeFile")
            ?: System.getenv("ANDROID_KEYSTORE_PATH")
            ?: "")
            .trim()
    val releaseStorePassword =
        (keystoreProperties.getProperty("storePassword")
            ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
            ?: "")
            .trim()
    val releaseKeyAlias =
        (keystoreProperties.getProperty("keyAlias")
            ?: System.getenv("ANDROID_KEY_ALIAS")
            ?: "")
            .trim()
    val releaseKeyPassword =
        (keystoreProperties.getProperty("keyPassword")
            ?: System.getenv("ANDROID_KEY_PASSWORD")
            ?: "")
            .trim()
    val allowInsecureReleaseSigning =
        (System.getenv("ALLOW_INSECURE_DEBUG_SIGNING_FOR_RELEASE")
            ?: "false")
            .trim()
            .equals("true", ignoreCase = true)
    val isReleaseTaskRequested =
        gradle.startParameter.taskNames.any { taskName ->
            taskName.contains("Release", ignoreCase = true)
        }
    val hasReleaseSigning =
        releaseStoreFile.isNotEmpty() &&
            releaseStorePassword.isNotEmpty() &&
            releaseKeyAlias.isNotEmpty() &&
            releaseKeyPassword.isNotEmpty()

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.soobshio.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    androidResources {
        noCompress += "tflite"
    }

    buildTypes {
        release {
            signingConfig =
                when {
                    hasReleaseSigning -> signingConfigs.getByName("release")
                    allowInsecureReleaseSigning -> signingConfigs.getByName("debug")
                    else -> signingConfigs.getByName("debug")
                }
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            isJniDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    if (isReleaseTaskRequested && !hasReleaseSigning && !allowInsecureReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Provide keystore.properties or ANDROID_KEYSTORE_* env vars.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
