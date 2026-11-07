package com.example.model;

import java.util.List; // unused on purpose: its warning shows jdtls has published diagnostics for this file

public class Formal implements Greeting {
    @Override
    public String greet(String name) {
        return "Good day, " + name;
    }
}
