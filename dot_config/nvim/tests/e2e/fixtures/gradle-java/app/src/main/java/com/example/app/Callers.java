package com.example.app;

import com.example.model.Formal;
import com.example.model.Greeting;
import java.util.List; // unused on purpose: its warning shows jdtls has published diagnostics for this file

class Callers {
    static String throughInterface(Greeting greeting) {
        return greeting.greet("Ada");
    }

    static String throughClass(Formal formal) {
        return formal.greet("Ada");
    }
}
