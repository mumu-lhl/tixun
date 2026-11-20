plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val releaseStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")?.takeIf { it.isNotBlank() } ?: "tixun"
val hasReleaseSigning = !releaseStorePath.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() && !releaseKeyPassword.isNullOrBlank()

// Debug builds need no secrets; every Release build must use the owner's key.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project.path == ":app" && it.name.contains("Release") }) {
        check(hasReleaseSigning) { "Release signing is required. See docs/ANDROID_SIGNING.md." }
    }
}

android {
    namespace = "org.tixun.tixun"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures { aidl = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.tixun.tixun"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
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
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
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

val pythonJni = layout.buildDirectory.dir("generated/python-sandbox-jni")
android.sourceSets.getByName("main").jniLibs.srcDir(pythonJni.get().asFile)
val buildPythonSandbox by tasks.registering {
    inputs.dir("src/main/zig")
    inputs.file("../../scripts/build_android_python.sh")
    outputs.dir(pythonJni)
    doLast {
        val sdk = android.sdkDirectory.absolutePath
        val process = ProcessBuilder(
            "bash", "scripts/build_android_python.sh", sdk, android.ndkVersion,
            pythonJni.get().asFile.absolutePath,
        ).directory(rootProject.projectDir.parentFile).inheritIO().start()
        check(process.waitFor() == 0) { "Android Python launcher build failed" }
    }
}
tasks.named("preBuild").configure { dependsOn(buildPythonSandbox) }

// Keep signed packages and signing validation out of the Gradle task cache.
tasks.configureEach {
    if (name.startsWith("package") || name.startsWith("validateSigning")) {
        outputs.cacheIf { false }
    }
}
