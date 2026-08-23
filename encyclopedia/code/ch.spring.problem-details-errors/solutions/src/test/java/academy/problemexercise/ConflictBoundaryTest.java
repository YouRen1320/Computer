package academy.problemexercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import tools.jackson.databind.json.JsonMapper;

class ConflictBoundaryTest {
    private final JsonMapper mapper = JsonMapper.builder().build();
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new ConflictBoundary.ConflictController())
                .setControllerAdvice(new ConflictBoundary.ConflictAdvice())
                .build();
    }

    @Test
    void problemBodyUsesSafeStableContract() throws Exception {
        var result = mvc.perform(post("/work-orders/42/close")).andReturn();
        var wire = result.getResponse().getContentAsString();
        var body = mapper.readTree(wire);
        assertEquals(409, body.get("status").asInt());
        assertEquals("work-order.state-conflict", body.get("code").asString());
        assertEquals("/work-orders/42/close", body.get("instance").asString());
        assertFalse(wire.contains("internal state"));
        assertFalse(wire.contains("WorkOrderConflict"));
        assertFalse(wire.contains("stackTrace"));
    }

    @Test
    void httpStatusMustMatchProblemStatus() throws Exception {
        var result = mvc.perform(post("/work-orders/42/close")).andReturn();
        assertEquals(409, result.getResponse().getStatus(),
                "EXPECTED_NON_2XX_PROBLEM: do not wrap a conflict in HTTP 200");
        assertEquals(result.getResponse().getStatus(),
                mapper.readTree(result.getResponse().getContentAsString()).get("status").asInt());
    }
}
