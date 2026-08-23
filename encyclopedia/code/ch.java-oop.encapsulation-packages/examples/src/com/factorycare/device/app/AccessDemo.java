package com.factorycare.device.app;

import com.factorycare.device.domain.Device;
import com.factorycare.device.domain.PackageBoundaryProbe;

public class AccessDemo {
    public static void main(String[] args) {
        Device pump = new Device(" pump-01 ");
        System.out.println("code=" + pump.code());
        System.out.println("status=" + pump.status());
        pump.startRepair();
        System.out.println("after=" + pump.status());
        System.out.println("packageProbe=" + PackageBoundaryProbe.normalizeForDemo(" valve-02 "));
    }
}
