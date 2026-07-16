package academy.validation;

import static academy.validation.CreateWorkOrderRequest.Priority.HIGH;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Set;
import java.util.stream.Collectors;

import jakarta.validation.ConstraintViolation;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.converter.StringHttpMessageConverter;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import tools.jackson.databind.json.JsonMapper;

class ValidationExampleTest {
    private LocalValidatorFactoryBean validator;
    private RecordingCreateUseCase useCase;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();
        useCase = new RecordingCreateUseCase();
        mvc = MockMvcBuilders.standaloneSetup(new ValidatedWorkOrderController(useCase))
                .setValidator(validator)
                .setMessageConverters(new StringHttpMessageConverter(),
                        new JacksonJsonHttpMessageConverter(JsonMapper.builder().build()))
                .build();
    }

    @AfterEach
    void closeValidator() {
        validator.close();
    }

    @Test
    void validDtoHasNoViolations() {
        assertTrue(validator.validate(valid()).isEmpty());
    }

    @Test
    void fieldConstraintsExposeStablePaths() {
        var request = new CreateWorkOrderRequest(" ", "", null, null, null);
        assertEquals(Set.of("assetId", "description", "priority", "createdAt", "dueAt"), paths(request));
    }

    @Test
    void equalOrEarlierDeadlineUsesDueAtPath() {
        assertEquals(Set.of("dueAt"), paths(new CreateWorkOrderRequest("A", "D", HIGH, 10L, 10L)));
        assertEquals(Set.of("dueAt"), paths(new CreateWorkOrderRequest("A", "D", HIGH, 10L, 9L)));
    }

    @Test
    void crossFieldValidatorIsNullSafe() {
        var violations = validator.validate(new CreateWorkOrderRequest("A", "D", HIGH, null, 20L));
        assertEquals(Set.of("createdAt"), violations.stream()
                .map(v -> v.getPropertyPath().toString()).collect(Collectors.toSet()));
    }

    @Test
    void validHttpRequestReturns201AndCallsUseCaseOnce() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON).content(validJson()))
                .andExpect(status().isCreated()).andExpect(content().string("created=42"));
        assertEquals(1, useCase.callCount());
    }

    @Test
    void blankDescriptionReturns400BeforeUseCaseWithDescriptionPath() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"A\",\"description\":\" \",\"priority\":\"HIGH\",\"createdAt\":10,\"dueAt\":20}"))
                .andExpect(status().isBadRequest()).andReturn();
        assertEquals(Set.of("description"), mvcPaths(result.getResolvedException()));
        assertEquals(0, useCase.callCount());
    }

    @Test
    void crossFieldConflictReturns400BeforeUseCaseWithDueAtPath() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"A\",\"description\":\"D\",\"priority\":\"HIGH\",\"createdAt\":20,\"dueAt\":10}"))
                .andExpect(status().isBadRequest()).andReturn();
        assertEquals(Set.of("dueAt"), mvcPaths(result.getResolvedException()));
        assertEquals(0, useCase.callCount());
    }

    @Test
    void malformedJsonReturns400BeforeUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    private Set<String> paths(CreateWorkOrderRequest request) {
        return validator.validate(request).stream().map(v -> v.getPropertyPath().toString())
                .collect(Collectors.toSet());
    }

    private static Set<String> mvcPaths(Exception exception) {
        var failure = (MethodArgumentNotValidException) exception;
        return failure.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField()).collect(Collectors.toSet());
    }

    private static CreateWorkOrderRequest valid() {
        return new CreateWorkOrderRequest("ASSET-7", "pump vibration", HIGH, 10L, 20L);
    }

    private static String validJson() {
        return "{\"assetId\":\"ASSET-7\",\"description\":\"pump vibration\",\"priority\":\"HIGH\",\"createdAt\":10,\"dueAt\":20}";
    }
}
