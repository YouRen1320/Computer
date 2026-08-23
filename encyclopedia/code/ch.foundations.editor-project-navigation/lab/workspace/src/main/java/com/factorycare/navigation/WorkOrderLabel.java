package com.factorycare.navigation;

final class WorkOrderLabel {
    // SOURCE_OF_TRUTH
    static String label(String status) {
        return "work-order:" + status;
    }
}
