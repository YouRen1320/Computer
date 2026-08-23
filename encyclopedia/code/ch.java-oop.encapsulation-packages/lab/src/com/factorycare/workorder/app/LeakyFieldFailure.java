package com.factorycare.workorder.app;

public class LeakyFieldFailure {
    public static void main(String[] args) {
        LeakyOrder order = new LeakyOrder();
        order.status = "UNKNOWN_FROM_UI";
        if ("UNKNOWN_FROM_UI".equals(order.status)) {
            System.err.println("PUBLIC_FIELD_LEAK expected=CREATED actual=UNKNOWN_FROM_UI");
            System.exit(8);
        }
    }

    static final class LeakyOrder {
        public String status = "CREATED";
    }
}
