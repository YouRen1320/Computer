package com.factorycare.learning;

public class RepairCost {
    public static int calculate(int laborMinutes, int ratePerHourCents, int partsCents) {
        return laborMinutes * ratePerHourCents / 60 + partsCents;
    }
}
