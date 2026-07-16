import java.util.ArrayList;
import java.util.List;

public final class ExceptionContractsDemo {
    private ExceptionContractsDemo() {
    }

    record Request(String requestKey, String title) {
    }

    record WorkOrder(String id) {
    }

    static final class DuplicateWorkOrderException extends Exception {
        private final String requestKey;

        DuplicateWorkOrderException(String requestKey) {
            super("work order already exists");
            this.requestKey = requestKey;
        }

        String requestKey() {
            return requestKey;
        }
    }

    static final class InvalidWorkOrderRequestException extends RuntimeException {
        InvalidWorkOrderRequestException(String message) {
            super(message);
        }
    }

    static final class GatewayAccessException extends Exception {
        GatewayAccessException(String message) {
            super(message);
        }
    }

    static final class WorkOrderCreationException extends RuntimeException {
        WorkOrderCreationException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    interface WorkOrderGateway {
        WorkOrder insert(Request request) throws DuplicateWorkOrderException, GatewayAccessException;
    }

    static final class WorkOrderCreator {
        private final WorkOrderGateway gateway;

        WorkOrderCreator(WorkOrderGateway gateway) {
            this.gateway = gateway;
        }

        WorkOrder create(Request request) throws DuplicateWorkOrderException {
            if (request == null || request.title() == null || request.title().isBlank()) {
                throw new InvalidWorkOrderRequestException("title must have text");
            }
            try {
                return gateway.insert(request);
            } catch (GatewayAccessException cause) {
                throw new WorkOrderCreationException("unable to create work order", cause);
            }
        }
    }

    static String handle(WorkOrderCreator creator, Request request) {
        try {
            return "CREATED:" + creator.create(request).id();
        } catch (InvalidWorkOrderRequestException invalid) {
            return "INVALID_INPUT:" + invalid.getMessage();
        } catch (DuplicateWorkOrderException conflict) {
            return "CONFLICT:" + conflict.requestKey();
        } catch (WorkOrderCreationException system) {
            String cause = system.getCause() == null ? "missing" : system.getCause().getClass().getSimpleName();
            return "SYSTEM_ERROR:cause=" + cause;
        }
    }

    static final class TraceScope implements AutoCloseable {
        private final String name;
        private final List<String> events;
        private final boolean failOnClose;

        TraceScope(String name, List<String> events, boolean failOnClose) {
            this.name = name;
            this.events = events;
            this.failOnClose = failOnClose;
            events.add("open:" + name);
        }

        @Override
        public void close() throws Exception {
            events.add("close:" + name);
            if (failOnClose) {
                throw new Exception("close failed:" + name);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        int[] successCalls = {0};
        WorkOrderCreator successCreator = new WorkOrderCreator(request -> {
            successCalls[0]++;
            return new WorkOrder("WO-1001");
        });
        String success = handle(successCreator, new Request("REQ-1", "bearing noise"));
        assertions = check("CREATED:WO-1001".equals(success), "success mapping", assertions);
        assertions = check(successCalls[0] == 1, "success gateway once", assertions);

        int[] invalidCalls = {0};
        WorkOrderCreator invalidCreator = new WorkOrderCreator(request -> {
            invalidCalls[0]++;
            return new WorkOrder("unexpected");
        });
        String invalid = handle(invalidCreator, new Request("REQ-2", " "));
        assertions = check("INVALID_INPUT:title must have text".equals(invalid), "input mapping", assertions);
        assertions = check(invalidCalls[0] == 0, "invalid request has no side effect", assertions);

        WorkOrderCreator duplicateCreator = new WorkOrderCreator(request -> {
            throw new DuplicateWorkOrderException(request.requestKey());
        });
        String conflict = handle(duplicateCreator, new Request("REQ-7", "motor heat"));
        assertions = check("CONFLICT:REQ-7".equals(conflict), "checked conflict mapping", assertions);
        assertions = expectDuplicateKey(duplicateCreator, assertions);

        WorkOrderCreator unavailableCreator = new WorkOrderCreator(request -> {
            throw new GatewayAccessException("adapter unavailable");
        });
        String system = handle(unavailableCreator, new Request("REQ-9", "sensor offline"));
        assertions = check("SYSTEM_ERROR:cause=GatewayAccessException".equals(system), "system mapping", assertions);
        assertions = expectPreservedCause(unavailableCreator, assertions);

        List<String> orderEvents = new ArrayList<>();
        try (TraceScope first = new TraceScope("A", orderEvents, false);
                TraceScope second = new TraceScope("B", orderEvents, false)) {
            orderEvents.add("use");
        }
        String order = String.join(",", orderEvents);
        assertions = check("open:A,open:B,use,close:B,close:A".equals(order), "reverse close order", assertions);
        assertions = check(orderEvents.size() == 5, "all resource events", assertions);

        List<String> suppressedEvents = new ArrayList<>();
        String primary = "";
        int suppressedCount = -1;
        String suppressedFirst = "";
        try (TraceScope scope = new TraceScope("C", suppressedEvents, true)) {
            throw new IllegalStateException("operation failed");
        } catch (IllegalStateException failure) {
            primary = failure.getMessage();
            suppressedCount = failure.getSuppressed().length;
            suppressedFirst = failure.getSuppressed()[0].getMessage();
        }
        assertions = check("operation failed".equals(primary), "primary failure retained", assertions);
        assertions = check(suppressedCount == 1, "one suppressed close failure", assertions);
        assertions = check("close failed:C".equals(suppressedFirst), "suppressed message", assertions);
        assertions = check(suppressedEvents.equals(List.of("open:C", "close:C")), "failed scope still closed", assertions);
        assertions = check(new InvalidWorkOrderRequestException("x") instanceof RuntimeException,
                "input failure unchecked", assertions);
        assertions = check(new DuplicateWorkOrderException("x") instanceof Exception,
                "conflict failure checked branch", assertions);

        System.out.println("success=" + success);
        System.out.println("invalid=" + invalid);
        System.out.println("conflict=" + conflict);
        System.out.println("system=" + system);
        System.out.println("resource.order=" + order);
        System.out.println("suppressed.primary=" + primary);
        System.out.println("suppressed.count=" + suppressedCount);
        System.out.println("suppressed.first=" + suppressedFirst);
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int expectDuplicateKey(WorkOrderCreator creator, int assertions) {
        try {
            creator.create(new Request("REQ-7", "motor heat"));
            throw new AssertionError("duplicate must fail");
        } catch (DuplicateWorkOrderException expected) {
            return check("REQ-7".equals(expected.requestKey()), "conflict key retained", assertions);
        }
    }

    private static int expectPreservedCause(WorkOrderCreator creator, int assertions) {
        try {
            creator.create(new Request("REQ-9", "sensor offline"));
            throw new AssertionError("gateway failure must be translated");
        } catch (DuplicateWorkOrderException impossible) {
            throw new AssertionError(impossible);
        } catch (WorkOrderCreationException expected) {
            return check(expected.getCause() instanceof GatewayAccessException,
                    "gateway cause preserved", assertions);
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
