package com.example.app

import com.example.mixed.JavaGreeter
import com.example.mixed.KotlinFormatter

fun headline(name: String): String = KotlinFormatter().shout(JavaGreeter().greet(name))

fun main() {
    // `!!` on a non-null String on purpose: kotlin-lsp warns about it, proving diagnostics for this file arrived
    println(headline("Ada")!!)
}
