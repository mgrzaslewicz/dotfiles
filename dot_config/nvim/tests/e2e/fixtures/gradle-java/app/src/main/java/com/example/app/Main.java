package com.example.app;

import com.example.model.Person;
import java.util.List; // unused on purpose: its warning shows jdtls has published diagnostics for this file

public class Main {
    public static void main(String[] args) {
        Person person = new Person("Ada");
        System.out.println(greeting(person.getName()));
    }

    static String greeting(String name) {
        return "Hello, " + name;
    }
}
