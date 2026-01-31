plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- AUTOMAÇÃO SAAS ---
// Tenta ler do comando de build. Se não vier nada, usa o padrão "Agen Pets"
val customAppId = project.findProperty("targetAppId") as String? ?: "com.agenpets.padrao"
val customAppName = project.findProperty("targetAppName") as String? ?: "Agen Pets"
// ----------------------

android {
    namespace = "com.example.agenpet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // AQUI ESTÁ A MÁGICA: O ID vem da variável
        applicationId = customAppId
        
        // Define o nome base do app (pode ser sobrescrito nos flavors abaixo)
        resValue("string", "app_name", customAppName)

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    flavorDimensions.add("app")

    productFlavors {
        create("cliente") {
            dimension = "app"
            // Mantém o ID original passado no comando (ex: com.agenpets.afazendinha)
            applicationId = customAppId 
            // Mantém o nome original (ex: A Fazendinha)
            resValue("string", "app_name", customAppName) 
        }

        create("profissional") {
            dimension = "app"
            // Adiciona um sufixo para o app Pro não substituir o app Cliente
            // Ex: com.agenpets.afazendinha.pro
            applicationIdSuffix = ".pro" 
            // Adiciona "Pro" ao nome. Ex: A Fazendinha Pro
            resValue("string", "app_name", "$customAppName Pro") 
        }
    }
}

flutter {
    source = "../.."
}