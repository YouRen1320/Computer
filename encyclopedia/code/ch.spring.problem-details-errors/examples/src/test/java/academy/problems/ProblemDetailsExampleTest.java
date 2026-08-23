package academy.problems;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

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

class ProblemDetailsExampleTest {
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
    void normalResponseIsNotWrappedByAdvice() throws Exception {
        var result = mvc.perform(get("/work-orders/7").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andReturn();
        var body = body(result);
        assertEquals(7, body.get("id").asInt());
        assertEquals("IN_PROGRESS", body.get("status").asString());
        assertFalse(body.has("type"));
        assertFalse(body.has("code"));
    }

    @Test
    void validCreateStillReturns201() throws Exception {
        var result = mvc.perform(post("/work-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"ASSET-7\",\"description\":\"pump vibration\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        assertEquals("CREATED", body(result).get("status").asString());
        assertEquals(0, reporter.count());
    }

    @Test
    void validationFailureUsesStable400ProblemAndSortedErrors() throws Exception {
        var result = mvc.perform(post("/work-orders")
                        .header("X-Trace-Id", "trace-validation")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\" \",\"description\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andReturn();
        var problem = body(result);
        assertProblem(problem, 400, "validation", "Request validation failed",
                "request.invalid", "/work-orders", "trace-validation");
        assertEquals(List.of("assetId", "description"),
                problem.get("errors").valueStream()
                        .map(item -> item.get("path").asString()).toList());
        assertTrue(problem.get("errors").valueStream()
                .allMatch(item -> "required".equals(item.get("code").asString())));
    }

    @Test
    void missingWorkOrderUses404Problem() throws Exception {
        var result = mvc.perform(get("/work-orders/404").header("X-Trace-Id", "trace-404"))
                .andExpect(status().isNotFound())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andReturn();
        assertProblem(body(result), 404, "work-order-not-found", "Work order not found",
                "work-order.not-found", "/work-orders/404", "trace-404");
    }

    @Test
    void invalidCloseUses409Problem() throws Exception {
        var result = mvc.perform(post("/work-orders/42/close")
                        .header("X-Current-State", "IN_PROGRESS")
                        .header("X-Trace-Id", "trace-409"))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andReturn();
        assertProblem(body(result), 409, "work-order-conflict", "Work order state conflict",
                "work-order.state-conflict", "/work-orders/42/close", "trace-409");
    }

    @Test
    void unknownFailureUsesSafe500WithoutInternalDetails() throws Exception {
        var result = mvc.perform(get("/work-orders/500").header("X-Trace-Id", "trace-500"))
                .andExpect(status().isInternalServerError())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andReturn();
        var text = result.getResponse().getContentAsString();
        assertProblem(body(result), 500, "internal-error", "Internal server error",
                "internal.error", "/work-orders/500", "trace-500");
        assertFalse(text.contains("SQLException"));
        assertFalse(text.contains("select secret_token"));
        assertFalse(text.contains("IllegalStateException"));
        assertFalse(text.contains("stackTrace"));
    }

    @Test
    void serverReporterKeepsTraceAndOriginalFailure() throws Exception {
        mvc.perform(get("/work-orders/500").header("X-Trace-Id", "trace-cause"))
                .andExpect(status().isInternalServerError());
        assertEquals(1, reporter.count());
        assertEquals("trace-cause", reporter.traceId());
        assertTrue(reporter.failure() instanceof IllegalStateException);
        assertTrue(reporter.failure().getCause().getMessage().contains("SQLException"));
    }

    @Test
    void everyHttpStatusMatchesBodyStatus() throws Exception {
        var validation = mvc.perform(post("/work-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"\",\"description\":\"\"}"))
                .andReturn();
        var missing = mvc.perform(get("/work-orders/404")).andReturn();
        var conflict = mvc.perform(post("/work-orders/1/close")).andReturn();
        var unknown = mvc.perform(get("/work-orders/500")).andReturn();
        for (var result : List.of(validation, missing, conflict, unknown)) {
            assertEquals(result.getResponse().getStatus(), body(result).get("status").asInt());
        }
    }

    @Test
    void untrustedTraceHeaderIsNotReflected() throws Exception {
        var result = mvc.perform(get("/work-orders/404")
                        .header("X-Trace-Id", "bad trace with spaces and token=secret"))
                .andExpect(status().isNotFound())
                .andReturn();
        assertEquals("generated-test-trace", body(result).get("traceId").asString());
        assertFalse(result.getResponse().getContentAsString().contains("token=secret"));
    }

    private JsonNode body(MvcResult result) throws Exception {
        return mapper.readTree(result.getResponse().getContentAsString());
    }

    private static void assertProblem(
            JsonNode problem,
            int status,
            String typeSuffix,
            String title,
            String code,
            String instance,
            String traceId) {
        assertEquals("https://factorycare.example/problems/" + typeSuffix,
                problem.get("type").asString());
        assertEquals(title, problem.get("title").asString());
        assertEquals(status, problem.get("status").asInt());
        assertTrue(problem.get("detail").asString().length() > 10);
        assertEquals(instance, problem.get("instance").asString());
        assertEquals(code, problem.get("code").asString());
        assertEquals(traceId, problem.get("traceId").asString());
    }
}
