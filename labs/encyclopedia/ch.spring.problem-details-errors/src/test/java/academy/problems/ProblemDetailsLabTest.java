package academy.problems;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class ProblemDetailsLabTest {
    private JsonMapper mapper;
    private LocalValidatorFactoryBean validator;
    private ProblemFixtures.RecordingFailureReporter reporter;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mapper = JsonMapper.builder().build();
        validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();
        reporter = new ProblemFixtures.RecordingFailureReporter();
        mvc = MockMvcBuilders.standaloneSetup(new ProblemFixtures.WorkOrderController())
                .setControllerAdvice(new ProblemFixtures.ApiProblemAdvice(reporter))
                .setValidator(validator)
                .build();
    }

    @AfterEach
    void closeValidator() {
        validator.close();
    }

    @Test
    void normalQueryRemainsPlainSuccessContract() throws Exception {
        var result = mvc.perform(get("/work-orders/7"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andReturn();
        assertEquals(Set.of("id", "status"), Set.copyOf(body(result).propertyNames()));
    }

    @Test
    void validCreateRemains201() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"A-7\",\"description\":\"pump vibration\"}"))
                .andExpect(status().isCreated());
        assertEquals(0, reporter.count());
    }

    @Test
    void validCloseRemains200() throws Exception {
        var result = mvc.perform(post("/work-orders/7/close")
                        .header("X-Current-State", "VERIFIED"))
                .andExpect(status().isOk())
                .andReturn();
        assertEquals("CLOSED", body(result).get("status").asString());
    }

    @Test
    void validationProduces400AndSortedStructuredErrors() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"\",\"description\":\" \"}"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andReturn();
        var problem = body(result);
        assertContract(problem, 400, "validation", "request.invalid", "/work-orders");
        assertEquals(List.of("assetId", "description"), problem.get("errors").valueStream()
                .map(item -> item.get("path").asString()).toList());
    }

    @Test
    void missingProducesStable404() throws Exception {
        var result = mvc.perform(get("/work-orders/404"))
                .andExpect(status().isNotFound()).andReturn();
        assertContract(body(result), 404, "work-order-not-found",
                "work-order.not-found", "/work-orders/404");
    }

    @Test
    void invalidStateProducesStable409() throws Exception {
        var result = mvc.perform(post("/work-orders/7/close")
                        .header("X-Current-State", "IN_PROGRESS"))
                .andExpect(status().isConflict()).andReturn();
        assertContract(body(result), 409, "work-order-conflict",
                "work-order.state-conflict", "/work-orders/7/close");
    }

    @Test
    void unknownProducesSafe500() throws Exception {
        var result = mvc.perform(get("/work-orders/500"))
                .andExpect(status().isInternalServerError()).andReturn();
        var wire = result.getResponse().getContentAsString();
        assertContract(body(result), 500, "internal-error", "internal.error", "/work-orders/500");
        for (var forbidden : List.of("SQLException", "secret_token", "IllegalStateException",
                "stackTrace", "academy.problems")) {
            assertFalse(wire.contains(forbidden), forbidden);
        }
    }

    @Test
    void unknownKeepsTraceAndCauseInServerReporter() throws Exception {
        mvc.perform(get("/work-orders/500").header("X-Trace-Id", "trace-lab"))
                .andExpect(status().isInternalServerError());
        assertEquals("trace-lab", reporter.traceId());
        assertEquals(1, reporter.count());
        assertTrue(reporter.failure().getCause().getMessage().contains("SQLException"));
    }

    @Test
    void allFourFailuresKeepHttpAndBodyStatusEqual() throws Exception {
        var validation = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"\",\"description\":\"\"}"))
                .andReturn();
        var missing = mvc.perform(get("/work-orders/404")).andReturn();
        var conflict = mvc.perform(post("/work-orders/7/close")).andReturn();
        var unknown = mvc.perform(get("/work-orders/500")).andReturn();
        for (var result : List.of(validation, missing, conflict, unknown)) {
            assertEquals(result.getResponse().getStatus(), body(result).get("status").asInt());
            assertTrue(result.getResponse().getContentType().startsWith("application/problem+json"));
        }
    }

    @Test
    void knownClientFailuresDoNotPolluteUnknownFailureReporter() throws Exception {
        mvc.perform(get("/work-orders/404")).andExpect(status().isNotFound());
        mvc.perform(post("/work-orders/7/close")).andExpect(status().isConflict());
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"\",\"description\":\"\"}"))
                .andExpect(status().isBadRequest());
        assertEquals(0, reporter.count());
    }

    private JsonNode body(MvcResult result) throws Exception {
        return mapper.readTree(result.getResponse().getContentAsString());
    }

    private static void assertContract(
            JsonNode problem, int status, String type, String code, String instance) {
        assertEquals("https://factorycare.example/problems/" + type,
                problem.get("type").asString());
        assertTrue(problem.get("title").asString().length() > 5);
        assertEquals(status, problem.get("status").asInt());
        assertTrue(problem.get("detail").asString().length() > 10);
        assertEquals(instance, problem.get("instance").asString());
        assertEquals(code, problem.get("code").asString());
        assertTrue(problem.has("traceId"));
    }
}
