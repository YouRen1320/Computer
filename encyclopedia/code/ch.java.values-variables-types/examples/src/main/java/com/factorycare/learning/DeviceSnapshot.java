package com.factorycare.learning;

public class DeviceSnapshot {
    public static void main(String[] args) {
        int riskLevel = 4;
        int maintenanceCycleDays = 180;
        int openTicketCount = 3;
        long deviceId = 100000001L;
        float humidityPercent = 58.5F;
        double temperatureCelsius = 36.5;
        char zoneCode = 'A';
        boolean enabled = true;
        String deviceName = "A区-空压机-01";

        String statusText = "待确认";
        statusText = "运行中";

        System.out.println("=== FactoryCare 设备快照 ===");
        System.out.print("设备名称：");
        System.out.println(deviceName);
        System.out.printf("设备ID=%d, 区域=%c%n", deviceId, zoneCode);
        System.out.printf("工单数=%d, 启用=%b, 状态=%s%n",
                openTicketCount, enabled, statusText);
        System.out.printf("风险级别=%d, 维护周期天数=%d%n",
                riskLevel, maintenanceCycleDays);
        System.out.printf("温度=%s, 湿度=%s%n",
                temperatureCelsius, humidityPercent);

        {
            String displaySection = "设备摘要";
            System.out.println(displaySection);
        }

        {
            String displaySection = "检查结果";
            System.out.println(displaySection);
        }
    }
}
