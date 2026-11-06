// Builds ball.jar: the Viewpoint addon "projectgolf.ball" that draws the golf ball in 3D.
//
//   gradlew.bat build        (Windows)   or   ./gradlew build
//
// It compiles against the Viewpoint.jar of your Viewpoint install (compile only: the API is never copied into
// ball.jar, which Viewpoint would refuse), then copies ball.jar into the ProjectGolfViewpoint mod.
// Another Viewpoint.jar:  gradlew.bat build -PviewpointJar=C:\path\to\Viewpoint.jar

plugins {
    java
}

val viewpointJar: String = (findProperty("viewpointJar") as String?)
    ?: "../../Viewpoint/Contents/mods/Viewpoint/42/media/java/client/Viewpoint.jar"

tasks.withType<JavaCompile> {
    options.release = 17          // Viewpoint loads Java 17 bytecode
    options.encoding = "UTF-8"
    options.compilerArgs.add("-Xlint:all")
}

dependencies {
    compileOnly(files(viewpointJar))
}

tasks.jar {
    archiveFileName = "ball.jar"
    // safety net: never ship Viewpoint's classes
    exclude("viewpoint/**")
}

val installAddon by tasks.registering(Copy::class) {
    from(tasks.jar)
    into(layout.projectDirectory.dir("../Contents/mods/ProjectGolfViewpoint/common/media/viewpoint/addons/projectgolf.ball"))
}

tasks.build {
    finalizedBy(installAddon)
}
