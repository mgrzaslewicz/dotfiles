Fixture for tests/e2e/test_gradle_java.lua and tests/test_replay_gradle_java.lua: multi-module Gradle build (`model`
with Lombok and an interface with one implementation, `app` with JUnit 5 and `Callers`, which calls the interface
method through the interface type and through the class), no wrapper (Gradle comes from mise). Tests copy it to a
temp dir; never build in place.
