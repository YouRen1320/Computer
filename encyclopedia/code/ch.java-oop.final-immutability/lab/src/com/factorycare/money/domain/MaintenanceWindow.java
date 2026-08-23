package com.factorycare.money.domain;

public final class MaintenanceWindow {
    private final int[] hours;

    public MaintenanceWindow(int[] hours) {
        if (hours == null || hours.length == 0) {
            throw new IllegalArgumentException("hours must not be empty");
        }
        for (int hour : hours) {
            if (hour < 0 || hour > 23) {
                throw new IllegalArgumentException("hour out of range");
            }
        }
        this.hours = hours.clone();
    }

    public int[] hours() {
        return hours.clone();
    }
}
