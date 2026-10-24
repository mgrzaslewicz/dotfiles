package com.example.mixed

// Kotlin calling Java.
fun main() {
    // `!!` on a non-null String on purpose: kotlin-lsp warns about it, proving diagnostics for this file arrived
    println(KotlinFormatter().shout(JavaGreeter().greet("Ada"))!!)
}
