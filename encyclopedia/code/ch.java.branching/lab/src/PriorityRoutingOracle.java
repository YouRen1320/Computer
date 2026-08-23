public class PriorityRoutingOracle {
    public static void main(String[] args) {
        int assertions = 0;

        int priority = 1;
        int routeCode;
        if (priority < 1 || priority > 5) {
            routeCode = -1;
        } else if (priority == 5) {
            routeCode = 3;
        } else if (priority >= 3) {
            routeCode = 2;
        } else {
            routeCode = 1;
        }
        assert routeCode == 1;
        assertions++;

        priority = 3;
        if (priority < 1 || priority > 5) {
            routeCode = -1;
        } else if (priority == 5) {
            routeCode = 3;
        } else if (priority >= 3) {
            routeCode = 2;
        } else {
            routeCode = 1;
        }
        assert routeCode == 2;
        assertions++;

        priority = 5;
        if (priority < 1 || priority > 5) {
            routeCode = -1;
        } else if (priority == 5) {
            routeCode = 3;
        } else if (priority >= 3) {
            routeCode = 2;
        } else {
            routeCode = 1;
        }
        assert routeCode == 3;
        assertions++;

        priority = 0;
        if (priority < 1 || priority > 5) {
            routeCode = -1;
        } else if (priority == 5) {
            routeCode = 3;
        } else if (priority >= 3) {
            routeCode = 2;
        } else {
            routeCode = 1;
        }
        assert routeCode == -1;
        assertions++;

        priority = 6;
        if (priority < 1 || priority > 5) {
            routeCode = -1;
        } else if (priority == 5) {
            routeCode = 3;
        } else if (priority >= 3) {
            routeCode = 2;
        } else {
            routeCode = 1;
        }
        assert routeCode == -1;
        assertions++;

        assert 1 < 3;
        assertions++;
        assert !(5 < 3);
        assertions++;
        assert 3 >= 3 && 3 < 5;
        assertions++;
        assert !(0 >= 1 && 0 <= 5);
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }
}
