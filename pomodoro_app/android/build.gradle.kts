allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
}
buildscript {
    
    repositories {
        google()  
        mavenCentral() 
    }
    extra["coreLibraryDesugaringEnabled"] = true

    dependencies {
        
        classpath("com.android.tools.build:gradle:7.4.0")
        classpath ("com.google.gms:google-services:4.3.15")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.21") // Kotlin プラグイン
    }
}




val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
