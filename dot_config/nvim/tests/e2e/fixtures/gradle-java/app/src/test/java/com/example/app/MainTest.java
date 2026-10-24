package com.example.app;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class MainTest {
    @Test
    void greets() {
        assertEquals("Hello, Ada", Main.greeting("Ada"));
    }

    @Test
    void failsOnPurpose() {
        assertEquals("Hi, Ada", Main.greeting("Ada"));
    }
}
