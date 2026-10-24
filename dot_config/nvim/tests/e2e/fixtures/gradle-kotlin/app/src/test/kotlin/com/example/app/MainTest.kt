package com.example.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class MainTest {
    @Test
    fun greets() {
        assertEquals("Hello, Ada", greeting("Ada"))
    }

    @Test
    fun failsOnPurpose() {
        assertEquals("Hi, Ada", greeting("Ada"))
    }
}
