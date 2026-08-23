package com.factorycare.learning;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DowntimeCostTest {
    @Test
    void calculatesDowntimeCost() {
        assertEquals(12_000, DowntimeCost.calculate(200, 60));
    }

    @Test
    void returnsZeroForZeroMinutes() {
        assertEquals(0, DowntimeCost.calculate(200, 0));
    }
}
