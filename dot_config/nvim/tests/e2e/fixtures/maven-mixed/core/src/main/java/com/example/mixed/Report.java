package com.example.mixed;

// Java calling Kotlin: compiles with Gradle; whether jdtls resolves it is what the test pins.
public class Report {
    public String headline(String name) {
        return new KotlinFormatter().shout(new JavaGreeter().greet(name));
    }
}
