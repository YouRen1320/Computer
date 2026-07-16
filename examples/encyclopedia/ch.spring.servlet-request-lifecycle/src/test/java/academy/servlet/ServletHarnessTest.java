package academy.servlet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ServletHarnessTest {
    @Test
    void filterChainReachesServletAndUnwindsInReverse() throws Exception {
        List<String> events = new ArrayList<>();
        var servlet = new ServletHarness.WorkOrderServlet(events);
        var response = ServletHarness.response();

        ServletHarness.invoke(
                List.of(new ServletHarness.TraceFilter(events), new ServletHarness.RequiredEquipmentFilter()),
                servlet,
                ServletHarness.request("GET", "/work-orders", "req-17", Map.of("equipmentId", "EQ-7")),
                response.response());

        assertEquals(List.of("before:req-17", "servlet:req-17", "after:req-17"), events);
        assertEquals(1, servlet.calls());
        assertEquals(200, response.state().status());
        assertEquals("req-17", response.state().header("X-Request-Id"));
        assertEquals("equipment=EQ-7", response.state().body());
        assertTrue(response.state().committed());
    }

    @Test
    void validationFilterBuildsComplete400AndDoesNotCallServlet() throws Exception {
        List<String> events = new ArrayList<>();
        var servlet = new ServletHarness.WorkOrderServlet(events);
        var response = ServletHarness.response();

        ServletHarness.invoke(
                List.of(new ServletHarness.RequiredEquipmentFilter()),
                servlet,
                ServletHarness.request("GET", "/work-orders", "req-18", Map.of()),
                response.response());

        assertEquals(0, servlet.calls());
        assertEquals(400, response.state().status());
        assertEquals("missing equipmentId", response.state().body());
        assertTrue(response.state().committed());
    }

    @Test
    void statusChangeAfterCommitCannotRewriteResponse() throws Exception {
        var response = ServletHarness.response();

        ServletHarness.invoke(
                List.of(),
                new ServletHarness.LateStatusServlet(),
                ServletHarness.request("GET", "/late", "req-19", Map.of()),
                response.response());

        assertEquals(200, response.state().status());
        assertEquals("partial", response.state().body());
        assertEquals(1, response.state().lateStatusAttempts());
    }

    @Test
    void silentFilterStopsTheChainWithoutProducingAResponse() throws Exception {
        List<String> events = new ArrayList<>();
        var servlet = new ServletHarness.WorkOrderServlet(events);
        var response = ServletHarness.response();

        ServletHarness.invoke(
                List.of(new ServletHarness.StoppingFilter()),
                servlet,
                ServletHarness.request("GET", "/work-orders", "req-20", Map.of("equipmentId", "EQ-9")),
                response.response());

        assertEquals(0, servlet.calls());
        assertEquals("", response.state().body());
        assertTrue(!response.state().committed());
    }

    @Test
    void retainingRequestInSharedStateMakesTheLatestRequestOverwriteTheEarlierOne() {
        var retaining = new ServletHarness.RetainingHandler();
        retaining.retain(ServletHarness.request(
                "GET", "/work-orders", "req-A", Map.of("equipmentId", "EQ-A")));
        assertEquals("EQ-A", retaining.currentEquipment());

        retaining.retain(ServletHarness.request(
                "GET", "/work-orders", "req-B", Map.of("equipmentId", "EQ-B")));

        assertEquals("EQ-B", retaining.currentEquipment());
    }
}
