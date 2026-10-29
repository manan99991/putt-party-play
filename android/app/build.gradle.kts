plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.handytools.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.tenzy.toolkit"
        minSdk = 26
        targetSdk = 36
        // Auto-incrementing versionCode from the CI run number so every uploaded bundle is unique
        // and strictly increasing (Play rejects reused codes; a stale code leaves old bundles active).
        versionCode = (System.getenv("VERSION_CODE")?.toIntOrNull() ?: 3)
        versionName = "1.0.2"

        // AdMob app ID (identifies the app; it doesn't serve ads itself).
        manifestPlaceholders["admobAppId"] = "ca-app-pub-5414801919054534~4620337988"

        // Live ads only in a production build invoked with -PliveAds=true. Every other build —
        // debug AND the internal-testing release — uses Google's reserved TEST ad units, which are
        // always safe to view and tap. Viewing/tapping your own LIVE ads is an AdMob policy
        // violation that can disable the account, so testing must never touch them.
        buildConfigField("boolean", "LIVE_ADS", (project.findProperty("liveAds")?.toString() ?: "false"))

        // INTERNAL TESTING ONLY: -PinternalUnlock=true makes every install behave as Tenzy Pro —
        // no ads, no quotas, no paywall — so testers exercise every tool at full. Defaults to
        // false; CI sets it for the internal track. MUST be false for any production release
        // (a Pro-unlock backdoor in production is a store-rejection risk).
        buildConfigField("boolean", "INTERNAL_UNLOCK", (project.findProperty("internalUnlock")?.toString() ?: "false"))
    }

    // Upload key. CI decodes ANDROID_KEYSTORE_B64 into android/upload.jks; locally, put your
    // upload.jks there and export the same four env vars. Without them the release bundle is
    // produced unsigned; sign it with: jarsigner -keystore upload.jks app-release.aab handytools
    val ks = rootProject.file("upload.jks")
    signingConfigs {
        if (ks.exists()) create("upload") {
            storeFile = ks
            // Upload-key credentials. The keystore FILE (ANDROID_KEYSTORE_B64 secret) is the secret;
            // these literals are only an upload key (resettable via Play) and are useless without it,
            // so baking them in removes a fragile hand-paste step. Env still overrides for local dev.
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "02f1e8a007cb5a908b28844a4f0457eb"
            keyAlias = System.getenv("KEY_ALIAS") ?: "tenzy"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "02f1e8a007cb5a908b28844a4f0457eb"
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
    implementation("com.google.android.ump:user-messaging-platform:3.1.0")
    implementation("com.android.billingclient:billing-ktx:8.0.0")

    // Screen OCR + image labeling (AI tools)
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:image-labeling:17.0.9")

    // Tool ports: barcodes, translate, segmentation, doc scanner, video, exif, camera
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1")
    implementation("com.google.android.gms:play-services-mlkit-subject-segmentation:16.0.0-beta1")
    implementation("androidx.media3:media3-transformer:1.5.1")
    implementation("androidx.media3:media3-effect:1.5.1")
    implementation("androidx.media3:media3-common:1.5.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    // Word Finder: PDF text extraction on-device
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
}
