package com.factorycare.device.app;

import com.factorycare.device.domain.Device;

public class EncapsulationChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device pump = new Device(" pump-01 ");
        check("PUMP-01".equals(pump.code()), "normalized code"); assertions++;
        check("REGISTERED".equals(pump.status()), "default status"); assertions++;
        pump.startRepair();
        check("IN_REPAIR".equals(pump.status()), "repair status"); assertions++;
        expectRepeatedStart(pump); assertions++;
        expectInvalid(null); assertions++;
        expectInvalid(" "); assertions++;
        Device second = new Device("VALVE-02");
        check("REGISTERED".equals(second.status()), "independent second status"); assertions++;
        check(pump != second, "independent identity"); assertions++;
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    static void expectRepeatedStart(Device device) {
        try {
            device.startRepair();
            throw new AssertionError("repeated start accepted");
        } catch (IllegalStateException expected) {
            // Expected.
        }
    }

    static void expectInvalid(String code) {
        try {
            new Device(code);
            throw new AssertionError("invalid code accepted");
        } catch (IllegalArgumentException expected) {
            // Expected.
        }
    }

    static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
