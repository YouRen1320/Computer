import java.util.ArrayList;
import java.util.List;

public final class ExceptionContractsLab {
    private ExceptionContractsLab() {
    }

    record Request(String key, String title) {
    }

    record WorkOrder(String id) {
    }

    record Outcome(String code, String detail, String causeName) {
    }

    static final class DuplicateWorkOrderException extends Exception {
        private final String key;

        DuplicateWorkOrderException(String key) {
            super("duplicate request key");
            this.key = key;
        }

        String key() {
            return key;
        }
    }

    static final class InvalidRequestException extends RuntimeException {
        InvalidRequestException(String message) {
            super(message);
        }
    }

    static final class GatewayException extends Exception {
        GatewayException(String message) {
            super(message);
        }
    }

    static final class CreationException extends RuntimeException {
        CreationException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    interface Gateway {
        WorkOrder insert(Request request) throws DuplicateWorkOrderException, GatewayException;
    }

    static final class Creator {
        private final Gateway gateway;

        Creator(Gateway gateway) {
            this.gateway = gateway;
        }

        WorkOrder create(Request request) throws DuplicateWorkOrderException {
            if (request == null || request.title() == null || request.title().isBlank()) {
                throw new InvalidRequestException("title must have text");
            }
            try {
                return gateway.insert(request);
            } catch (GatewayException cause) {
                throw new CreationException("create operation failed", cause);
            }
        }
    }

    static Outcome execute(Creator creator, Request request) {
        try {
            return new Outcome("CREATED", creator.create(request).id(), "none");
        } catch (InvalidRequestException invalid) {
            return new Outcome("INVALID_INPUT", invalid.getMessage(), "none");
        } catch (DuplicateWorkOrderException conflict) {
            return new Outcome("CONFLICT", conflict.key(), "none");
        } catch (CreationException system) {
            Throwable cause = system.getCause();
            return new Outcome("SYSTEM_ERROR", "create unavailable",
                    cause == null ? "missing" : cause.getClass().getSimpleName());
        }
    }

    static final class Scope implements AutoCloseable {
        private final String name;
        private final List<String> events;
        private final boolean closeFails;

        Scope(String name, List<String> events, boolean closeFails) {
            this.name = name;
            this.events = events;
            this.closeFails = closeFails;
            events.add("open:" + name);
        }

        @Override
        public void close() throws Exception {
            events.add("close:" + name);
            if (closeFails) {
                throw new Exception("close failed:" + name);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        int[] successCalls = {0};
        Creator successCreator = new Creator(request -> {
            successCalls[0]++;
            return new WorkOrder("WO-2001");
        });
        Outcome success = execute(successCreator, new Request("REQ-1", "pump vibration"));
        assertions = check("CREATED".equals(success.code()), "success code", assertions);
        assertions = check("WO-2001".equals(success.detail()), "success detail", assertions);
        assertions = check(successCalls[0] == 1, "success side effect once", assertions);

        int[] invalidCalls = {0};
        Creator invalidCreator = new Creator(request -> {
            invalidCalls[0]++;
            return new WorkOrder("unexpected");
        });
        Outcome invalid = execute(invalidCreator, new Request("REQ-2", ""));
        assertions = check("INVALID_INPUT".equals(invalid.code()), "invalid code", assertions);
        assertions = check("title must have text".equals(invalid.detail()), "invalid detail", assertions);
        assertions = check(invalidCalls[0] == 0, "invalid has no gateway call", assertions);

        Creator conflictCreator = new Creator(request -> {
            throw new DuplicateWorkOrderException(request.key());
        });
        Outcome conflict = execute(conflictCreator, new Request("REQ-7", "motor heat"));
        assertions = check("CONFLICT".equals(conflict.code()), "conflict code", assertions);
        assertions = check("REQ-7".equals(conflict.detail()), "conflict key", assertions);

        Creator systemCreator = new Creator(request -> {
            throw new GatewayException("adapter down");
        });
        Outcome system = execute(systemCreator, new Request("REQ-9", "sensor offline"));
        assertions = check("SYSTEM_ERROR".equals(system.code()), "system code", assertions);
        assertions = check("GatewayException".equals(system.causeName()), "system cause report", assertions);
        try {
            systemCreator.create(new Request("REQ-9", "sensor offline"));
            throw new AssertionError("system path must fail");
        } catch (DuplicateWorkOrderException impossible) {
            throw new AssertionError(impossible);
        } catch (CreationException expected) {
            assertions = check(expected.getCause() instanceof GatewayException, "cause retained", assertions);
            assertions = check("create operation failed".equals(expected.getMessage()), "safe outer message", assertions);
        }

        List<String> orderedEvents = new ArrayList<>();
        try (Scope first = new Scope("A", orderedEvents, false);
                Scope second = new Scope("B", orderedEvents, false)) {
            orderedEvents.add("use");
        }
        String order = String.join(",", orderedEvents);
        assertions = check("open:A,open:B,use,close:B,close:A".equals(order), "reverse close", assertions);
        assertions = check(orderedEvents.size() == 5, "resource event count", assertions);

        List<String> failedEvents = new ArrayList<>();
        IllegalStateException primary = null;
        try (Scope scope = new Scope("C", failedEvents, true)) {
            throw new IllegalStateException("operation failed");
        } catch (IllegalStateException failure) {
            primary = failure;
        }
        assertions = check(primary != null && "operation failed".equals(primary.getMessage()),
                "primary retained", assertions);
        assertions = check(primary != null && primary.getSuppressed().length == 1,
                "suppressed count", assertions);
        assertions = check(primary != null && "close failed:C".equals(primary.getSuppressed()[0].getMessage()),
                "suppressed message", assertions);
        assertions = check(failedEvents.equals(List.of("open:C", "close:C")), "failed scope closed", assertions);

        Exception checked = new DuplicateWorkOrderException("REQ-X");
        RuntimeException unchecked = new InvalidRequestException("bad");
        assertions = check(!(checked instanceof RuntimeException), "conflict is checked", assertions);
        assertions = check(unchecked instanceof RuntimeException, "input is unchecked", assertions);

        System.out.println("report.success=" + success);
        System.out.println("report.invalid=" + invalid);
        System.out.println("report.conflict=" + conflict);
        System.out.println("report.system=" + system);
        System.out.println("resource.order=" + order);
        System.out.println("suppressed.primary=" + primary.getMessage());
        System.out.println("suppressed.count=" + primary.getSuppressed().length);
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
