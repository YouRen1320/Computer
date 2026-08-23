package com.factorycare.learning;

public final class WorkOrderCost {
    private WorkOrderCost() {
    }

    public static int laborCostCents(int hourlyRateCents, int minutes) {
        if (hourlyRateCents < 0 || minutes < 0) {
            throw new IllegalArgumentException("rate and minutes must be non-negative");
        }
        return Math.multiplyExact(hourlyRateCents, minutes) / 60;
    }
}
