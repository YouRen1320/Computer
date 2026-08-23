package com.factorycare.learning;

/*
 * This class keeps every structure used by the chapter in one small file.
 * The comments are intentionally in English so the source is portable across
 * terminals; the chapter explains each line in Chinese.
 */
public class ProgramStructureDemo {
    public static void main(String[] args) {
        // A string literal is passed to a method invocation statement.
        System.out.println("FactoryCare structure ready.");

        {
            // This extra pair of braces is a nested block.
            System.out.println("Nested block reached.");
        }
    }
}
