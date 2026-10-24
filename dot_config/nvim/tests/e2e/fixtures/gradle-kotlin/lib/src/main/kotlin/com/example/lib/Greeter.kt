package com.example.lib

class Greeter(private val greeting: String) {
    fun greet(name: String): String = "$greeting, $name"
}
