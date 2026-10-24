package com.example.mixed;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class JavaGreeterTest {
    @Test
    void greets() {
        assertEquals("Hello, Ada", new JavaGreeter().greet("Ada"));
    }

    @Test
    void failsOnPurpose() {
        assertEquals("Hi, Ada", new JavaGreeter().greet("Ada"));
    }
}
