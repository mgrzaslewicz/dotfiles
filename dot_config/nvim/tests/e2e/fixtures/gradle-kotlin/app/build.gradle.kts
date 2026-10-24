plugins {
    kotlin("jvm")
    application
}

application { mainClass = "com.example.app.MainKt" }

dependencies {
    implementation(project(":lib"))
    testImplementation(platform("org.junit:junit-bom:5.14.4"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test { useJUnitPlatform() }
