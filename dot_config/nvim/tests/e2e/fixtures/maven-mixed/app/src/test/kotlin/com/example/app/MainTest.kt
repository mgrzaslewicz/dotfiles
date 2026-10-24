package com.example.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class MainTest {
    @Test
    fun headline() {
        assertEquals("HELLO, ADA!", headline("Ada"))
    }

    @Test
    fun failsOnPurpose() {
        assertEquals("Hello, Ada", headline("Ada"))
    }
}
