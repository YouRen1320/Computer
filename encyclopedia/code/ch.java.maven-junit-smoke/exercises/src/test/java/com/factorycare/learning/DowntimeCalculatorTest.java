package com.factorycare.learning;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class DowntimeCalculatorTest {
    @Test void sumsMultipleSegments() {
        assertEquals(45, DowntimeCalculator.totalMinutes(new int[]{10, 20, 15}));
    }

    @Test void returnsZeroForEmptyArray() {
        assertEquals(0, DowntimeCalculator.totalMinutes(new int[]{}));
    }
}
