plugins {
    id("com.android.library") version "8.7.3"
    id("org.jetbrains.kotlin.android") version "2.0.21"
}

// Keep in sync with the Godot editor version the project uses.
val godotVersion = "4.7.2.stable"

// Keep in sync with _get_android_dependencies() in addons/stepio_health/export_plugin.gd.
// 1.1.0 stable needs Android Gradle plugin 8.9.1, but Godot 4.7's Android build
// template uses 8.6.1, so use the April 2025 release candidate until it catches up.
val healthConnectVersion = "1.1.0-rc01"
val coroutinesVersion = "1.9.0"

android {
    namespace = "io.stepio.health"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    compileOnly("org.godotengine:godot:$godotVersion")
    implementation("androidx.health.connect:connect-client:$healthConnectVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")
}

// Builds and copies the AARs into the Godot addon so the Android export picks them up:
//   ./gradlew copyAarsToAddon
val copyAarsToAddon by tasks.registering(Copy::class) {
    dependsOn("assemble")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("*.aar")
    into(rootDir.resolve("../../addons/stepio_health/bin/android"))
}
