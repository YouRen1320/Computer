package academy.mvc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

class WorkOrderControllerLabTest {
    private InMemoryWorkOrderQuery query;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        query = new InMemoryWorkOrderQuery();
        mvc = MockMvcBuilders.standaloneSetup(new WorkOrderController(query)).build();
    }

    @Test
    void detailBindsPathAndHeaderAndReturns200() throws Exception {
        mvc.perform(get("/work-orders/42").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Contract", "work-order-detail"))
                .andExpect(content().string("WO-42:CREATED"));
        assertEquals(1, query.callCount());
    }

    @Test
    void validMissingResourceReturns404AfterQueryCall() throws Exception {
        mvc.perform(get("/work-orders/99").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isNotFound());
        assertEquals(1, query.callCount());
    }

    @Test
    void pathTypeMismatchReturns400BeforeControllerCall() throws Exception {
        mvc.perform(get("/work-orders/abc").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
        assertEquals(0, query.callCount());
    }

    @Test
    void zeroIdReturns400BeforeQueryCall() throws Exception {
        mvc.perform(get("/work-orders/0").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
        assertEquals(0, query.callCount());
    }

    @Test
    void missingHeaderReturns400() throws Exception {
        mvc.perform(get("/work-orders/42")).andExpect(status().isBadRequest());
    }

    @Test
    void blankHeaderReturns400() throws Exception {
        mvc.perform(get("/work-orders/42").header("X-Tenant-Id", ""))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listDefaultsAreBoundPredictably() throws Exception {
        mvc.perform(get("/work-orders").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(content().string("page=0,size=20,tenant=tenant-a,items=WO-42"));
    }

    @Test
    void listExplicitInputsAreBoundPredictably() throws Exception {
        mvc.perform(get("/work-orders").param("page", "3").param("size", "10")
                        .header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(content().string("page=3,size=10,tenant=tenant-a,items=WO-42"));
    }

    @Test
    void negativePageAndOversizedPageBothReturn400() throws Exception {
        mvc.perform(get("/work-orders").param("page", "-1")
                        .header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/work-orders").param("size", "101")
                        .header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unknownPathReturns404WithoutQueryCall() throws Exception {
        mvc.perform(get("/not-registered")).andExpect(status().isNotFound());
        assertEquals(0, query.callCount());
    }

    @Test
    void wrongMethodReturns405() throws Exception {
        mvc.perform(post("/work-orders/42").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void duplicateMappingsFailDuringHandlerRegistration() {
        assertThrows(IllegalStateException.class,
                () -> MockMvcBuilders.standaloneSetup(new CollisionOne(), new CollisionTwo()).build(),
                "EXPECTED_UNIQUE_ROUTE: the same request must not register two handlers");
    }

    @RestController
    static class CollisionOne {
        @GetMapping("/collision")
        String first() { return "one"; }
    }

    @RestController
    static class CollisionTwo {
        @GetMapping("/collision")
        String second() { return "two"; }
    }
}
