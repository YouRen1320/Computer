package com.factorycare.device.domain;

public final class PackageBoundaryProbe {
    private PackageBoundaryProbe() {
    }

    public static String normalizeForDemo(String raw) {
        return DeviceCodePolicy.normalize(raw);
    }
}
