package com.factorycare.navigation;

final class DeviceStatusFormatter {
    // SOURCE_OF_TRUTH: production definition
    static String formatStatus(String status) {
        return "status=" + status;
    }
}
