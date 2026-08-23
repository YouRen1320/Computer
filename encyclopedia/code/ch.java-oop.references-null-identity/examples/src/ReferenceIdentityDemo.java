public class ReferenceIdentityDemo {
    public static void main(String[] args) {
        Device primary = new Device();
        primary.code = "PUMP-01";
        primary.status = "IDLE";

        Device alias = primary;
        Device sameState = new Device();
        sameState.code = "PUMP-01";
        sameState.status = "IDLE";
        Device missing = null;
        String literalCode = "PUMP-01";
        String rebuiltCode = new String(new char[]{'P', 'U', 'M', 'P', '-', '0', '1'});
        String missingText = null;
        String emptyText = "";
        String blankText = " \t";

        System.out.println("alias.sameIdentity=" + (primary == alias));
        System.out.println("sameState.sameIdentity=" + (primary == sameState));
        System.out.println("sameState.sameFields=" + sameFields(primary, sameState));

        alias.status = "RUNNING";
        System.out.println("primary.statusAfterAliasWrite=" + primary.status);
        System.out.println("missing.isNull=" + (missing == null));
        System.out.println("missing.label=" + labelOf(missing));
        System.out.println("text.sameIdentity=" + (literalCode == rebuiltCode));
        System.out.println("text.sameContent=" + literalCode.equals(rebuiltCode));
        System.out.println("text.missing=" + (missingText == null));
        System.out.println("text.empty=" + emptyText.isEmpty());
        System.out.println("text.blank=" + blankText.isBlank());
    }

    static boolean sameFields(Device left, Device right) {
        return left.code.equals(right.code) && left.status.equals(right.status);
    }

    static String labelOf(Device device) {
        if (device == null) {
            return "<missing>";
        }
        return device.code + ":" + device.status;
    }

    // 本章把它当作现成的对象盒子；类声明的语法在下一章解释。
    static final class Device {
        String code;
        String status;
    }
}
