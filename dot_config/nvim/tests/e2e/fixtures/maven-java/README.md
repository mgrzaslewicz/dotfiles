Fixture for tests/e2e/test_maven_java.lua and tests/test_replay_maven_java.lua: multi-module Maven build (`model` with
Lombok, `app` with JUnit 5), the sources of gradle-java without its interface, no wrapper (Maven comes from mise).
Tests copy it to a temp dir; never build in place.
