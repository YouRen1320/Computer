package com.factorycare.workorder.domain;

final class StatusPolicy {
    private StatusPolicy() {
    }

    static void requireCurrent(String actual, String required) {
        if (!required.equals(actual)) {
            throw new IllegalStateException("required=" + required + " actual=" + actual);
        }
    }
}
