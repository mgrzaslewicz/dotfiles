package com.example.lib

class Formal : Greeting {
    // `!!` on a non-null String on purpose: kotlin-lsp warns about it, proving diagnostics for this file arrived
    override fun greet(name: String): String = "Good day, $name"!!
}
