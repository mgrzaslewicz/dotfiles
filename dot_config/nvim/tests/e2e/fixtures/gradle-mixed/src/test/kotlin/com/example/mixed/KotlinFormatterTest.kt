package com.example.mixed

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class KotlinFormatterTest {
    @Test
    fun shouts() {
        assertEquals("HI!", KotlinFormatter().shout("hi"))
    }

    @Test
    fun failsOnPurpose() {
        assertEquals("hi", KotlinFormatter().shout("hi"))
    }
}
