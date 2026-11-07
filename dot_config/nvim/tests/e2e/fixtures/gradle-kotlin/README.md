Fixture for tests/e2e/test_gradle_kotlin.lua and tests/test_replay_gradle_kotlin.lua: Kotlin-only multi-module Gradle
build (`lib` with an interface and one implementation, `app` with `fun main` and JUnit 5 tests), no wrapper. Tests
copy it to a temp dir; never build in place.
