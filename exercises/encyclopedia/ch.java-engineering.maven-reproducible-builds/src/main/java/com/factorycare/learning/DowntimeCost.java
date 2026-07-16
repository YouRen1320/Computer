package com.factorycare.learning;

public final class DowntimeCost {
    private DowntimeCost() {
    }

    public static int calculate(int centsPerMinute, int minutes) {
        return Math.multiplyExact(centsPerMinute, minutes);
    }
}
