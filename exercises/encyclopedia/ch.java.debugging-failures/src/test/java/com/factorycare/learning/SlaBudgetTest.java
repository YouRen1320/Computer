package com.factorycare.learning;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class SlaBudgetTest {
    @Test void subtractsElapsedTime() { assertEquals(45, SlaBudget.remainingMinutes(60, 15)); }
    @Test void preservesZeroValues() { assertEquals(0, SlaBudget.remainingMinutes(0, 0)); }
}
