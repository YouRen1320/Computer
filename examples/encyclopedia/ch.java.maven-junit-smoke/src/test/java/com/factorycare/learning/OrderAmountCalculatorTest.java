package com.factorycare.learning;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class OrderAmountCalculatorTest {
    @Test
    void calculatesTotalForMultipleItems() {
        int result = OrderAmountCalculator.calculateTotalCents(1999, 3);
        assertEquals(5997, result);
    }

    @Test
    void returnsZeroWhenQuantityIsZero() {
        int result = OrderAmountCalculator.calculateTotalCents(1999, 0);
        assertEquals(0, result);
    }
}
