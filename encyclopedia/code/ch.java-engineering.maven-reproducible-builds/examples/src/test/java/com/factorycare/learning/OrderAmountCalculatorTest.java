package com.factorycare.learning;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class OrderAmountCalculatorTest {
    @Test
    void calculatesNormalOrder() {
        assertEquals(5_997, OrderAmountCalculator.calculateTotalCents(1_999, 3));
    }

    @Test
    void rejectsNegativeQuantity() {
        assertThrows(IllegalArgumentException.class,
                () -> OrderAmountCalculator.calculateTotalCents(1_999, -1));
    }
}
