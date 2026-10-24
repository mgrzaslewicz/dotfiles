plugins {
    java
    kotlin("jvm") version "2.4.21"
    application
}

repositories { mavenCentral() }

application { mainClass = "com.example.mixed.MainKt" }

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.14.4"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test { useJUnitPlatform() }
