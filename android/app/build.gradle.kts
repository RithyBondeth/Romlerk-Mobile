import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) {
    releaseKeyFile.inputStream().use { releaseKeyProperties.load(it) }
}

android {
    namespace = "dev.romlerk.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time APIs
        // that predate the minSdk we support.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "dev.romlerk.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
            storeFile = releaseKeyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = releaseKeyProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Debug builds remain available without credentials. Release builds must fail
// before compilation rather than produce an unsigned or debug-signed artifact.
val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        check(releaseKeyFile.exists() && required.all {
            !releaseKeyProperties.getProperty(it).isNullOrBlank()
        }) {
            "Production signing is missing. Copy android/key.properties.example to android/key.properties and configure your upload keystore."
        }
        check(rootProject.file(releaseKeyProperties.getProperty("storeFile")).isFile) {
            "Production upload keystore was not found. Check storeFile in android/key.properties."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Gemini Nano through ML Kit. Still beta, and only present on supported
    // devices at runtime — LocalAiBridge treats every failure as "no enhanced
    // understanding here" and the app falls back to its own parser.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")
    // local_auth shows its prompt from a FragmentActivity, and needs an
    // AppCompat theme to do so on Android 8 and below.
    implementation("androidx.appcompat:appcompat:1.7.1")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
