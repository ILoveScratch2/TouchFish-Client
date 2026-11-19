import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release 签名配置
//
// Signed by Wang Xiehang
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val keystoreStoreFile: File? = keystoreProperties.getProperty("storeFile")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?.let { raw ->
        val direct = File(raw)
        when {
            direct.isAbsolute -> direct
            project.file(raw).exists() -> project.file(raw)
            else -> rootProject.file(raw)
        }
    }

val hasReleaseSigning = keystoreStoreFile?.isFile == true &&
    !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyPassword").isNullOrBlank()

android {
    namespace = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = keystoreStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // flutter_local_notifications 通过字符串 "ic_notification" 动态查找
            // smallIcon 资源（getIdentifier），R8/资源收缩器无法识别这种动态引用，
            // 会将其从 release APK 中移除，导致通知初始化抛出
            // "The resource ic_notification could not be found" 异常。
            // 修复方式：在 res/xml/keep.xml 中用 tools:keep 保留该资源，
            // 而不是关闭整个 release 的资源/代码收缩（那会让 APK 显著变大）。
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.15.0")
}

flutter {
    source = "../.."
}
