package com.factorycare.learning;

public class SlaBudget {
    public static int remainingMinutes(int targetMinutes, int elapsedMinutes) {
        return targetMinutes + elapsedMinutes; // 注入的逻辑故障：应按契约求余量。
    }
}
