import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Optional release signing, read from the first key.properties found:
//   1. -PwearKeyProps=/path/to/key.properties
//   2. wear/key.properties (git-ignored)
//   3. /home/box/secure/pujoroute/key.properties (build machine's secure store)
// It must contain storeFile (absolute, or relative to wear/), storePassword, keyAlias, keyPassword.
// If none exists, assembleRelease produces an UNSIGNED APK. Never commit keys or keystores.
val keyPropsFile = listOfNotNull(
    (findProperty("wearKeyProps") as String?)?.let { file(it) },
    rootProject.file("key.properties"),
    file("/home/box/secure/pujoroute/key.properties"),
).firstOrNull { it.exists() } ?: rootProject.file("key.properties")
val keyProps = Properties().apply {
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { load(it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keyProps.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.pujoroute.wear"
    compileSdk = 36

    defaultConfig {
        // Galaxy Store (separate listing): com.pujoroute.wear (default).
        // Google Play (same listing as the phone app): ./gradlew assembleRelease -PwearAppId=com.pujoroute.app
        applicationId = (findProperty("wearAppId") as String?) ?: "com.pujoroute.wear"
        minSdk = 30
        targetSdk = 36
        // Watch versionCodes live in 1000+ so they never clash with the phone app's codes.
        versionCode = 1001
        versionName = "1.0.0"
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else null
            // Galaxy Watch / Wear OS devices are ARM; the only native code is androidx.graphics.path (from Compose)
            ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = false
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all { it.systemProperty("screenshotDir", rootProject.file("screenshots").absolutePath) }
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.06.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("androidx.wear.compose:compose-navigation:1.4.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    // Voice / keyboard search via RemoteInput
    implementation("androidx.wear:wear-input:1.1.0")

    // Countdown Tile + days-left complication (pure AndroidX, no Google Play Services)
    implementation("androidx.wear.tiles:tiles:1.4.1")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("androidx.wear.protolayout:protolayout-material:1.2.1")
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
    implementation("androidx.wear.watchface:watchface-complications-data-source-ktx:1.2.1")

    testImplementation("junit:junit:4.13.2")
    // JVM screenshot tests (round 384/450 px, font scale 1.3), rendered with Robolectric native graphics
    testImplementation("org.robolectric:robolectric:4.16")
    testImplementation(composeBom)
    testImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
