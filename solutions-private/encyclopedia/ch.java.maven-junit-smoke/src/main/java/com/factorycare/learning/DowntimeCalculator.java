package com.factorycare.learning;

public class DowntimeCalculator {
    public static int totalMinutes(int[] segments) {
        int total = 0;
        for (int minutes : segments) total += minutes;
        return total;
    }
}
