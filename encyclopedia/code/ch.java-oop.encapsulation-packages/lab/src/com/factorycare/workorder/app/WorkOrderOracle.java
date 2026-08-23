package com.factorycare.workorder.app;

import com.factorycare.workorder.domain.WorkOrder;

public class WorkOrderOracle {
    public static void main(String[] args) {
        int assertions = 0;
        WorkOrder order = new WorkOrder(" WO-1001 ");
        check("WO-1001".equals(order.id()), "normalized id"); assertions++;
        check("CREATED".equals(order.status()), "created status"); assertions++;
        check(order.assigneeId() == null, "unassigned"); assertions++;

        order.assign(" TECH-07 ");
        check("TECH-07".equals(order.assigneeId()), "normalized assignee"); assertions++;
        check("ASSIGNED".equals(order.status()), "assigned status"); assertions++;
        order.start();
        check("IN_PROGRESS".equals(order.status()), "started status"); assertions++;

        try {
            order.start();
            throw new AssertionError("repeated start accepted");
        } catch (IllegalStateException expected) {
            assertions++;
        }
        try {
            order.assign("T-2");
            throw new AssertionError("reassignment accepted");
        } catch (IllegalStateException expected) {
            assertions++;
        }
        try {
            new WorkOrder(" ");
            throw new AssertionError("blank id accepted");
        } catch (IllegalArgumentException expected) {
            assertions++;
        }
        try {
            new WorkOrder(null);
            throw new AssertionError("null id accepted");
        } catch (IllegalArgumentException expected) {
            assertions++;
        }
        WorkOrder second = new WorkOrder("WO-1002");
        check(order != second, "separate objects"); assertions++;
        check("CREATED".equals(second.status()), "second independent"); assertions++;
        System.out.println("assertions=" + assertions + " passed");
    }

    static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
