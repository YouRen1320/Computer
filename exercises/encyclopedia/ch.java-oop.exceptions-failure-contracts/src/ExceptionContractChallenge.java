public final class ExceptionContractChallenge {
    private ExceptionContractChallenge() {
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
        DuplicateWorkOrderException(String message) {
            super(message);
        }
    }

    static final class GatewayException extends Exception {
        GatewayException(String message) {
            super(message);
        }
    }

    static final class CreationException extends RuntimeException {
        CreationException(String message) {
            super(message);
        }

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
            try {
                if (request == null || request.title() == null || request.title().isBlank()) {
                    throw new InvalidRequestException("title must have text");
                }
                return gateway.insert(request);
            } catch (DuplicateWorkOrderException conflict) {
                throw conflict;
            } catch (Exception ignoredTypeAndCause) {
                // TODO：不要把可修复输入误分类，也不要在转换时丢掉 cause。
                throw new CreationException("create failed");
            }
        }
    }

    static String handle(Creator creator, Request request) {
        try {
            return "CREATED:" + creator.create(request).id();
        } catch (InvalidRequestException invalid) {
            return "INVALID_INPUT:" + invalid.getMessage();
        } catch (DuplicateWorkOrderException conflict) {
            return "CONFLICT:" + conflict.getMessage();
        } catch (CreationException system) {
            return "SYSTEM_ERROR:cause=" + (system.getCause() == null
                    ? "missing" : system.getCause().getClass().getSimpleName());
        }
    }

    public static void main(String[] args) {
        int[] invalidCalls = {0};
        Creator invalidCreator = new Creator(request -> {
            invalidCalls[0]++;
            return new WorkOrder("unexpected");
        });
        String invalid = handle(invalidCreator, new Request("REQ-1", " "));
        if (!invalid.startsWith("INVALID_INPUT:")) {
            System.err.println("STARTER_INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=" + invalid);
            System.exit(8);
        }

        Creator unavailableCreator = new Creator(request -> {
            throw new GatewayException("adapter unavailable");
        });
        String system = handle(unavailableCreator, new Request("REQ-2", "sensor offline"));
        if (!"SYSTEM_ERROR:cause=GatewayException".equals(system)) {
            System.err.println("STARTER_CAUSE_LOST expected=GatewayException actual=" + system);
            System.exit(9);
        }

        int[] successCalls = {0};
        Creator successCreator = new Creator(request -> {
            successCalls[0]++;
            return new WorkOrder("WO-3001");
        });
        Creator conflictCreator = new Creator(request -> {
            throw new DuplicateWorkOrderException(request.key());
        });
        int assertions = 0;
        assertions = check("CREATED:WO-3001".equals(handle(successCreator,
                new Request("REQ-3", "bearing noise"))), "success", assertions);
        assertions = check(successCalls[0] == 1, "success once", assertions);
        assertions = check(invalidCalls[0] == 0, "invalid no side effect", assertions);
        assertions = check("CONFLICT:REQ-7".equals(handle(conflictCreator,
                new Request("REQ-7", "motor heat"))), "checked conflict", assertions);
        assertions = check("INVALID_INPUT:title must have text".equals(invalid), "invalid mapping", assertions);
        assertions = check("SYSTEM_ERROR:cause=GatewayException".equals(system), "system mapping", assertions);
        assertions = check(new InvalidRequestException("x") instanceof RuntimeException, "unchecked input", assertions);
        Exception checked = new DuplicateWorkOrderException("x");
        assertions = check(!(checked instanceof RuntimeException), "checked conflict", assertions);
        assertions = expectCause(unavailableCreator, assertions);
        assertions = check(successCreator != invalidCreator, "independent creators", assertions);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static int expectCause(Creator creator, int assertions) {
        try {
            creator.create(new Request("REQ-2", "sensor offline"));
            throw new AssertionError("system path must fail");
        } catch (DuplicateWorkOrderException impossible) {
            throw new AssertionError(impossible);
        } catch (CreationException expected) {
            return check(expected.getCause() instanceof GatewayException, "cause preserved", assertions);
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
