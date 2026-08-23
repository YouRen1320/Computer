package com.factorycare.learning;

public final class OrderAmountCalculator {
    private OrderAmountCalculator() {
    }

    public static int calculateTotalCents(int unitPriceCents, int quantity) {
        return unitPriceCents * quantity;
    }
}
