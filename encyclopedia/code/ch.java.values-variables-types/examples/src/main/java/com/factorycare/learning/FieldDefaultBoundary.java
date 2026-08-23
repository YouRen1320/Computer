package com.factorycare.learning;

public class FieldDefaultBoundary {
    static int ticketCount;
    static boolean enabled;
    static String note;

    public static void main(String[] args) {
        System.out.printf("ticketCount=%d, enabled=%b, note=%s%n",
                ticketCount, enabled, note);
    }
}
