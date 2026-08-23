package com.factorycare.learning;

public final class OrderAmountCalculator {
    private OrderAmountCalculator() {
    }

    public static int calculateTotalCents(int unitPriceCents, int quantity) {
        if (unitPriceCents < 0 || quantity < 0) {
            throw new IllegalArgumentException("price and quantity must be non-negative");
        }
        return Math.multiplyExact(unitPriceCents, quantity);
    }
}
