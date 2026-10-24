package com.example.app

import com.example.lib.Greeter

fun greeting(name: String): String = Greeter("Hello").greet(name)

fun main() {
    // `!!` on a non-null String on purpose: kotlin-lsp warns about it, proving diagnostics for this file arrived
    println(greeting("Ada")!!)
}
