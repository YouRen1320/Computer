package com.factorycare.workorder.app;

import com.factorycare.workorder.domain.WorkOrder;

public class WorkOrderLab {
    public static void main(String[] args) {
        WorkOrder order = new WorkOrder(" WO-1001 ");
        System.out.println("created=" + order.id() + "|" + order.status());
        order.assign(" TECH-07 ");
        System.out.println("assigned=" + order.assigneeId() + "|" + order.status());
        order.start();
        System.out.println("started=" + order.status());
    }
}
