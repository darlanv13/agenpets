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
            // Mantém o ID original passado no comando
            applicationId = customAppId 
            // Mantém o nome original
            resValue("string", "app_name", customAppName) 
        }

        create("profissional") {
            dimension = "app"
            
            // --- CORREÇÃO ---
            // Definimos o ID EXATO que está no seu JSON.
            // Isso sobrescreve o padrão "com.agenpets.padrao"
            applicationId = "com.agenpets.pro" 
            
            // Comente ou remova o sufixo, pois já definimos o ID completo acima
            // applicationIdSuffix = ".pro" 
            // ----------------

            resValue("string", "app_name", "Agenpets Pro") 
        }

        create("tenants") {
            dimension = "app"
            // Se for rodar este também sem config nova, comente a linha abaixo:
            // applicationIdSuffix = ".admin"
            resValue("string", "app_name", "Painel Admin Agenpets")
        }
    }
}

flutter {
    source = "../.."
}