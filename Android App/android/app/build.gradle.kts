import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material lives OUTSIDE the repo. Resolution order:
//   1. env PUJOROUTE_KEY_PROPERTIES (absolute path to key.properties)
//   2. /home/box/secure/pujoroute/key.properties (build machine default)
//   3. android/key.properties (gitignored, legacy local override)
// key.properties must contain storeFile (absolute path), storePassword, keyAlias, keyPassword.
// If none exists (e.g. CI), release builds fall back to the debug key; such builds
// must NOT be uploaded to any store.
val keystoreProperties = Properties()
val keystorePropertiesFile: File? = listOfNotNull(
    System.getenv("PUJOROUTE_KEY_PROPERTIES")?.takeIf { it.isNotBlank() }?.let { file(it) },
    file("/home/box/secure/pujoroute/key.properties"),
    rootProject.file("key.properties"),
).firstOrNull { it.isFile }
if (keystorePropertiesFile != null) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val releaseStoreFile: File? = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
val hasReleaseSigning = releaseStoreFile?.isFile == true &&
    listOf("storePassword", "keyAlias", "keyPassword").all { !keystoreProperties.getProperty(it).isNullOrBlank() }
if (!hasReleaseSigning) {
    logger.warn("PujoRoute: release keystore not found; release build will be signed with the DEBUG key.")
}

android {
    namespace = "com.pujoroute.app"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pujoroute.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // See keystore resolution above; falls back to the debug key when absent.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
