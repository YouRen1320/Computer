package academy.mvcexercise;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class MissingWorkOrderExerciseTest {
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new MissingWorkOrderController()).build();
    }

    @Test
    void existingResourceIsSuccessful() throws Exception {
        mvc.perform(get("/work-orders/42").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk())
                .andExpect(content().string("WO-42:OPEN"));
    }

    @Test
    void missingResourceUsesHttp404() throws Exception {
        int actualStatus = mvc.perform(
                        get("/work-orders/99").header("X-Tenant-Id", "tenant-a"))
                .andReturn().getResponse().getStatus();
        assertEquals(404, actualStatus,
                "EXPECTED_HTTP_404: a missing resource must not be encoded inside a 200 response");
    }
}
