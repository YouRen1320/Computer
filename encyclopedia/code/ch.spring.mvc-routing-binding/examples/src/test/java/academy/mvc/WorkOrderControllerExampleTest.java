package academy.mvc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class WorkOrderControllerExampleTest {
    private InMemoryWorkOrderQuery query;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        query = new InMemoryWorkOrderQuery();
        mvc = MockMvcBuilders.standaloneSetup(new WorkOrderController(query)).build();
    }

    @Test
    void existingDetailReturns200AndContractHeader() throws Exception {
        mvc.perform(get("/work-orders/42").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Contract", "work-order-detail"))
                .andExpect(content().string("WO-42:CREATED"));
    }

    @Test
    void missingResourceReturns404() throws Exception {
        mvc.perform(get("/work-orders/99").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isNotFound());
    }

    @Test
    void nonNumericPathVariableReturns400BeforeQueryCall() throws Exception {
        mvc.perform(get("/work-orders/not-a-number").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
        assertEquals(0, query.callCount());
    }

    @Test
    void nonPositiveIdReturns400() throws Exception {
        mvc.perform(get("/work-orders/0").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
        assertEquals(0, query.callCount());
    }

    @Test
    void missingRequiredTenantHeaderReturns400() throws Exception {
        mvc.perform(get("/work-orders/42")).andExpect(status().isBadRequest());
    }

    @Test
    void listUsesDocumentedPaginationDefaults() throws Exception {
        mvc.perform(get("/work-orders").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(content().string("page=0,size=20,tenant=tenant-a,items=WO-42"));
    }

    @Test
    void listBindsExplicitQueryParameters() throws Exception {
        mvc.perform(get("/work-orders").param("page", "2").param("size", "5")
                        .header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(content().string("page=2,size=5,tenant=tenant-a,items=WO-42"));
    }

    @Test
    void invalidPaginationReturns400() throws Exception {
        mvc.perform(get("/work-orders").param("page", "-1")
                        .header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unknownPathReturns404() throws Exception {
        mvc.perform(get("/unknown")).andExpect(status().isNotFound());
    }

    @Test
    void unsupportedMethodReturns405() throws Exception {
        mvc.perform(post("/work-orders/42").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isMethodNotAllowed());
    }
}
