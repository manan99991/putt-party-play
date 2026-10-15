plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.handytools.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.handytools.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        // AdMob app ID. Replace with yours from https://apps.admob.com before release.
        // This is Google's official TEST app id — safe to ship to internal testing.
        manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
    }

    // Upload key. CI decodes ANDROID_KEYSTORE_B64 into android/upload.jks; locally, put your
    // upload.jks there and export the same four env vars. Without them the release bundle is
    // produced unsigned; sign it with: jarsigner -keystore upload.jks app-release.aab handytools
    val ks = rootProject.file("upload.jks")
    signingConfigs {
        if (ks.exists()) create("upload") {
            storeFile = ks
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // No keystore -> unsigned bundle (sign later with jarsigner or let CI sign with secrets).
            if (ks.exists()) signingConfig = signingConfigs.getByName("upload")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("androidx.dynamicanimation:dynamicanimation:1.0.0")

    // Room (alarms, clipboard history, notification log, notes)
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    // Monetization
    implementation("com.google.android.gms:play-services-ads:23.6.0")
    implementation("com.android.billingclient:billing-ktx:7.1.1")

    // Screen OCR
    implementation("com.google.mlkit:text-recognition:16.0.1")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
}
