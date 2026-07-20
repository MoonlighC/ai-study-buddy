import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

data class ReleaseSigningValues(val storeFile: String, val keyAlias: String, val storePassword: String, val keyPassword: String)

fun releaseSigningValues(): ReleaseSigningValues? {
    val localFile = rootProject.file("key.properties")
    val local = Properties().apply { if (localFile.exists()) localFile.inputStream().use(::load) }
    val selected = System.getenv("RELEASE_SIGNING_SOURCE") ?: if (local.isNotEmpty()) "local" else "ci"
    if (selected != "local" && selected != "ci") throw GradleException("Release signing source must be local or ci.")
    val values = if (selected == "local") mapOf(
        "keystorePath" to local.getProperty("storeFile", ""), "keyAlias" to local.getProperty("keyAlias", ""),
        "storePassword" to local.getProperty("storePassword", ""), "keyPassword" to local.getProperty("keyPassword", ""),
    ) else mapOf(
        "keystorePath" to (System.getenv("ANDROID_KEYSTORE_PATH") ?: ""), "keyAlias" to (System.getenv("ANDROID_KEY_ALIAS") ?: ""),
        "storePassword" to (System.getenv("ANDROID_STORE_PASSWORD") ?: ""), "keyPassword" to (System.getenv("ANDROID_KEY_PASSWORD") ?: ""),
    )
    if (values.values.any { it.isBlank() }) return null
    return ReleaseSigningValues(values.getValue("keystorePath"), values.getValue("keyAlias"), values.getValue("storePassword"), values.getValue("keyPassword"))
}

val releaseSigning = releaseSigningValues()

fun missingReleaseSigningFields(): List<String> {
    val localFile = rootProject.file("key.properties")
    val local = Properties().apply { if (localFile.exists()) localFile.inputStream().use(::load) }
    val selected = System.getenv("RELEASE_SIGNING_SOURCE") ?: if (local.isNotEmpty()) "local" else "ci"
    val values = if (selected == "local") mapOf(
        "keystorePath" to local.getProperty("storeFile", ""), "keyAlias" to local.getProperty("keyAlias", ""),
        "storePassword" to local.getProperty("storePassword", ""), "keyPassword" to local.getProperty("keyPassword", ""),
    ) else mapOf(
        "keystorePath" to (System.getenv("ANDROID_KEYSTORE_PATH") ?: ""), "keyAlias" to (System.getenv("ANDROID_KEY_ALIAS") ?: ""),
        "storePassword" to (System.getenv("ANDROID_STORE_PASSWORD") ?: ""), "keyPassword" to (System.getenv("ANDROID_KEY_PASSWORD") ?: ""),
    )
    return values.filterValues { it.isBlank() }.keys.sorted()
}

android {
    namespace = "com.moonlightc.aistudybuddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.moonlightc.aistudybuddy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigning?.let { signing -> create("releaseUpload") {
            storeFile = file(signing.storeFile)
            keyAlias = signing.keyAlias
            storePassword = signing.storePassword
            keyPassword = signing.keyPassword
        }
        }
    }

    buildTypes {
        release {
            if (releaseSigning != null) signingConfig = signingConfigs.getByName("releaseUpload")
        }
    }
}

// Tester split APKs keep the app's declared build number. Flutter otherwise
// prefixes ABI-specific offsets (for example, arm64 build 3 becomes 2003).
android.applicationVariants.all {
    outputs.all {
        @Suppress("DEPRECATION")
        (this as com.android.build.gradle.api.ApkVariantOutput).versionCodeOverride = flutter.versionCode
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) } && releaseSigning == null) {
        throw GradleException("Release signing configuration is incomplete. Missing fields: ${missingReleaseSigningFields().joinToString(", ")}.")
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
