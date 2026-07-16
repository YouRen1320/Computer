import java.util.ArrayList;
import java.util.List;

public final class ExceptionContractSolution {
    private ExceptionContractSolution() {
    }

    record Request(String key, String title) {
    }

    record WorkOrder(String id) {
    }

    static final class InvalidRequestException extends RuntimeException {
        InvalidRequestException(String message) {
            super(message);
        }
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

    static String handle(Creator creator, Request request) {
        try {
            return "CREATED:" + creator.create(request).id();
        } catch (InvalidRequestException invalid) {
            return "INVALID_INPUT:" + invalid.getMessage();
        } catch (DuplicateWorkOrderException conflict) {
            return "CONFLICT:" + conflict.key();
        } catch (CreationException system) {
            return "SYSTEM_ERROR:cause=" + system.getCause().getClass().getSimpleName();
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
            return new WorkOrder("WO-4001");
        });
        String success = handle(successCreator, new Request("REQ-1", "bearing noise"));
        assertions = check("CREATED:WO-4001".equals(success), "success", assertions);
        assertions = check(successCalls[0] == 1, "success once", assertions);

        int[] invalidCalls = {0};
        Creator invalidCreator = new Creator(request -> {
            invalidCalls[0]++;
            return new WorkOrder("unexpected");
        });
        String invalid = handle(invalidCreator, new Request("REQ-2", " "));
        assertions = check("INVALID_INPUT:title must have text".equals(invalid), "invalid", assertions);
        assertions = check(invalidCalls[0] == 0, "invalid no side effect", assertions);

        Creator conflictCreator = new Creator(request -> {
            throw new DuplicateWorkOrderException(request.key());
        });
        String conflict = handle(conflictCreator, new Request("REQ-7", "motor heat"));
        assertions = check("CONFLICT:REQ-7".equals(conflict), "conflict", assertions);

        Creator systemCreator = new Creator(request -> {
            throw new GatewayException("adapter unavailable");
        });
        String system = handle(systemCreator, new Request("REQ-9", "sensor offline"));
        assertions = check("SYSTEM_ERROR:cause=GatewayException".equals(system), "system", assertions);
        try {
            systemCreator.create(new Request("REQ-9", "sensor offline"));
            throw new AssertionError("system path must fail");
        } catch (DuplicateWorkOrderException impossible) {
            throw new AssertionError(impossible);
        } catch (CreationException expected) {
            assertions = check(expected.getCause() instanceof GatewayException, "cause retained", assertions);
            assertions = check("create operation failed".equals(expected.getMessage()), "outer message", assertions);
        }

        List<String> orderEvents = new ArrayList<>();
        try (Scope first = new Scope("A", orderEvents, false);
                Scope second = new Scope("B", orderEvents, false)) {
            orderEvents.add("use");
        }
        String order = String.join(",", orderEvents);
        assertions = check("open:A,open:B,use,close:B,close:A".equals(order), "reverse close", assertions);

        List<String> failedEvents = new ArrayList<>();
        IllegalStateException primary = null;
        try (Scope scope = new Scope("C", failedEvents, true)) {
            throw new IllegalStateException("operation failed");
        } catch (IllegalStateException failure) {
            primary = failure;
        }
        assertions = check(primary != null && "operation failed".equals(primary.getMessage()), "primary", assertions);
        assertions = check(primary != null && primary.getSuppressed().length == 1, "suppressed count", assertions);
        assertions = check(primary != null && "close failed:C".equals(primary.getSuppressed()[0].getMessage()),
                "suppressed message", assertions);
        assertions = check(failedEvents.equals(List.of("open:C", "close:C")), "failed scope closed", assertions);
        Exception checked = new DuplicateWorkOrderException("REQ-X");
        assertions = check(!(checked instanceof RuntimeException), "checked conflict", assertions);
        assertions = check(new InvalidRequestException("x") instanceof RuntimeException,
                "unchecked input", assertions);

        System.out.println("solution.success=" + success);
        System.out.println("solution.invalid=" + invalid);
        System.out.println("solution.conflict=" + conflict);
        System.out.println("solution.system=" + system);
        System.out.println("solution.resource=" + order);
        System.out.println("solution.suppressed=" + primary.getSuppressed().length);
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
