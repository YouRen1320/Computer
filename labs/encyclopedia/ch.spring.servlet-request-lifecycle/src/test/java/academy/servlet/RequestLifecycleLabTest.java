package academy.servlet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;

class RequestLifecycleLabTest {
    @Test
    void concurrentRequestsKeepParametersInRequestLocalState() throws Exception {
        List<String> events = Collections.synchronizedList(new ArrayList<>());
        var servlet = new ServletHarness.WorkOrderServlet(events);
        try (var pool = Executors.newFixedThreadPool(4)) {
            List<Future<String>> futures = new ArrayList<>();
            for (int index = 0; index < 24; index++) {
                int requestNumber = index;
                futures.add(pool.submit(() -> {
                    var response = ServletHarness.response();
                    ServletHarness.invoke(
                            List.of(new ServletHarness.RequiredEquipmentFilter()),
                            servlet,
                            ServletHarness.request(
                                    "GET",
                                    "/work-orders",
                                    "req-" + requestNumber,
                                    Map.of("equipmentId", "EQ-" + requestNumber)),
                            response.response());
                    return response.state().body();
                }));
            }
            for (int index = 0; index < futures.size(); index++) {
                assertEquals("equipment=EQ-" + index, futures.get(index).get());
            }
        }
        assertEquals(24, servlet.calls());
    }

    @Test
    void finallySectionRunsWhenTargetThrows() {
        List<String> events = new ArrayList<>();
        HttpServlet broken = new HttpServlet() {
            @Override
            protected void doGet(HttpServletRequest request, HttpServletResponse response)
                    throws ServletException {
                throw new ServletException("EXPECTED_TARGET_FAILURE");
            }
        };

        ServletException error = assertThrows(ServletException.class, () -> ServletHarness.invoke(
                List.of(new ServletHarness.TraceFilter(events)),
                broken,
                ServletHarness.request("GET", "/broken", "req-fail", Map.of()),
                ServletHarness.response().response()));

        assertEquals("EXPECTED_TARGET_FAILURE", error.getMessage());
        assertEquals(List.of("before:req-fail", "after:req-fail"), events);
    }

    @Test
    void committedResponseRejectsBufferReset() throws Exception {
        var response = ServletHarness.response();
        ServletHarness.invoke(
                List.of(),
                new ServletHarness.LateStatusServlet(),
                ServletHarness.request("GET", "/late", "req-commit", Map.of()),
                response.response());

        IllegalStateException error = assertThrows(
                IllegalStateException.class, response.response()::resetBuffer);
        assertEquals("response already committed", error.getMessage());
    }

    @Test
    void asyncWorkUsesCopiedInputAndRunsOnNamedWorker() throws Exception {
        String callerThread = Thread.currentThread().getName();
        try (var worker = Executors.newSingleThreadExecutor(
                runnable -> Thread.ofPlatform().name("servlet-lab-worker").unstarted(runnable))) {
            var result = AsyncBoundary.submit(
                    ServletHarness.request(
                            "GET", "/async", "req-async", Map.of("equipmentId", "EQ-async")),
                    worker).toCompletableFuture().get();

            assertEquals("req-async", result.requestId());
            assertEquals("EQ-async", result.equipmentId());
            assertEquals("servlet-lab-worker", result.threadName());
            assertNotEquals(callerThread, result.threadName());
        }
    }

    @Test
    void synchronousFixtureMakesItsAsyncCapabilityExplicit() {
        var request = ServletHarness.request("GET", "/sync", "req-sync", Map.of());

        assertFalse(request.isAsyncSupported());
        assertFalse(request.isAsyncStarted());
        assertTrue(assertThrows(
                UnsupportedOperationException.class, request::startAsync)
                .getMessage().contains("startAsync"));
    }
}
