package com.factorycare.learning;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class WorkOrderCostTest {
    @ParameterizedTest
    @CsvSource({"6000, 30, 3000", "6000, 0, 0"})
    void calculatesLaborCost(int rate, int minutes, int expected) {
        assertEquals(expected, WorkOrderCost.laborCostCents(rate, minutes));
    }

    @Test
    void rejectsNegativeMinutes() {
        assertThrows(IllegalArgumentException.class,
                () -> WorkOrderCost.laborCostCents(6_000, -1));
    }
}
