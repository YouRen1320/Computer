package academy.validationexercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.converter.StringHttpMessageConverter;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import tools.jackson.databind.json.JsonMapper;

class ValidationBoundaryTest {
    private LocalValidatorFactoryBean validator;
    private ValidationBoundary.RecordingUseCase useCase;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();
        useCase = new ValidationBoundary.RecordingUseCase();
        mvc = MockMvcBuilders.standaloneSetup(new ValidationBoundary.WorkOrderController(useCase))
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
    void validRequestEntersUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"description\":\"pump vibration\"}"))
                .andExpect(status().isCreated());
        assertEquals(1, useCase.callCount());
    }

    @Test
    void blankDescriptionMustFailBeforeUseCase() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"description\":\" \"}"))
                .andReturn();
        assertEquals("400:0",
                result.getResponse().getStatus() + ":" + useCase.callCount(),
                "EXPECTED_VALIDATION_BEFORE_USE_CASE");
    }
}
