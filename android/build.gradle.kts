allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Required so the Flutter Gradle plugin can register its own afterEvaluate
// hooks on plugin subprojects (e.g. telephony) before they finish evaluating.
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    // Skip :app — it configures its own compileSdk in app/build.gradle.kts,
    // and calling afterEvaluate on :app here is what caused earlier crashes
    // (Flutter's own plugin already finishes evaluating :app first).
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let {
                it.compileSdkVersion(36)
            }
            // telephony (pub.dev) predates AGP's namespace requirement and
            // never declares one in its own build.gradle — inject it here
            // since we can't edit the package's file directly (pub_cache
            // gets overwritten on every `flutter pub get`).
            if (project.name == "telephony") {
                extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
                    if (android.namespace == null) {
                        android.namespace = "com.shounakmulay.telephony"
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}