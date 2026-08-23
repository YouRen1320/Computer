package academy.servlet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class EquipmentGuardFilterTest {
    @Test
    void validRequestContinuesExactlyOnce() throws Exception {
        AtomicInteger targetCalls = new AtomicInteger();
        FilterChain target = (request, response) -> targetCalls.incrementAndGet();

        new EquipmentGuardFilter().doFilter(
                request("EQ-42"), response().http(), target);

        assertEquals(1, targetCalls.get(), "EXPECTED_CHAIN_CONTINUATION");
    }

    @Test
    void missingIdentifierReturnsComplete400WithoutCallingTarget() throws Exception {
        AtomicInteger targetCalls = new AtomicInteger();
        ResponseFixture response = response();

        new EquipmentGuardFilter().doFilter(
                request(null), response.http(), (request, ignored) -> targetCalls.incrementAndGet());

        assertEquals(0, targetCalls.get());
        assertEquals(400, response.status());
        assertEquals("missing equipmentId", response.body());
        assertTrue(response.committed());
    }

    @Test
    void blankIdentifierIsRejected() throws Exception {
        AtomicInteger targetCalls = new AtomicInteger();
        ResponseFixture response = response();

        new EquipmentGuardFilter().doFilter(
                request("   "), response.http(), (request, ignored) -> targetCalls.incrementAndGet());

        assertEquals(0, targetCalls.get());
        assertEquals(400, response.status());
    }

    private static HttpServletRequest request(String equipmentId) {
        return (HttpServletRequest) Proxy.newProxyInstance(
                EquipmentGuardFilterTest.class.getClassLoader(),
                new Class<?>[] {HttpServletRequest.class},
                (proxy, method, arguments) -> switch (method.getName()) {
                    case "getParameter" -> equipmentId;
                    case "toString" -> "EquipmentRequest[" + equipmentId + "]";
                    case "hashCode" -> System.identityHashCode(proxy);
                    case "equals" -> proxy == arguments[0];
                    default -> throw new UnsupportedOperationException(method.getName());
                });
    }

    private static ResponseFixture response() {
        var state = new ResponseState();
        HttpServletResponse http = (HttpServletResponse) Proxy.newProxyInstance(
                EquipmentGuardFilterTest.class.getClassLoader(),
                new Class<?>[] {HttpServletResponse.class},
                (proxy, method, arguments) -> switch (method.getName()) {
                    case "setStatus" -> {
                        state.status = (int) arguments[0];
                        yield null;
                    }
                    case "getStatus" -> state.status;
                    case "getWriter" -> state.writer;
                    case "flushBuffer" -> {
                        state.writer.flush();
                        state.committed = true;
                        yield null;
                    }
                    case "isCommitted" -> state.committed;
                    case "toString" -> "EquipmentResponse[" + state.status + "]";
                    case "hashCode" -> System.identityHashCode(proxy);
                    case "equals" -> proxy == arguments[0];
                    default -> throw new UnsupportedOperationException(method.getName());
                });
        return new ResponseFixture(http, state);
    }

    private record ResponseFixture(HttpServletResponse http, ResponseState state) {
        int status() {
            return state.status;
        }

        String body() {
            state.writer.flush();
            return state.body.toString();
        }

        boolean committed() {
            return state.committed;
        }
    }

    private static final class ResponseState {
        private int status = 200;
        private boolean committed;
        private final StringWriter body = new StringWriter();
        private final PrintWriter writer = new PrintWriter(body);
    }
}
