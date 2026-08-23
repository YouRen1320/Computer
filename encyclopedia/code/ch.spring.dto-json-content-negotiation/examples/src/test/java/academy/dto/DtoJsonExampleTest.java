package academy.dto;

import static academy.dto.DtoFixtures.Priority.HIGH;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

class DtoJsonExampleTest {
    private JsonMapper mapper;
    private DtoFixtures.RecordingUseCase useCase;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mapper = JsonMapper.builder()
                .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
                .build();
        useCase = new DtoFixtures.RecordingUseCase();
        mvc = MockMvcBuilders.standaloneSetup(new DtoFixtures.WorkOrderJsonController(useCase))
                .setMessageConverters(new JacksonJsonHttpMessageConverter(mapper))
                .build();
    }

    @Test
    void requestDtoRoundTripsWithStableValues() throws Exception {
        var request = new DtoFixtures.CreateWorkOrderRequest("ASSET-7", "pump vibration", HIGH);
        assertEquals(request, mapper.readValue(mapper.writeValueAsString(request),
                DtoFixtures.CreateWorkOrderRequest.class));
    }

    @Test
    void requestAndResponseAreDifferentContracts() {
        assertNotEquals(DtoFixtures.CreateWorkOrderRequest.class, DtoFixtures.WorkOrderResponse.class);
    }

    @Test
    void responseMapperPublishesOnlyTheFiveContractFields() {
        var domain = new DtoFixtures.WorkOrder(42, "ASSET-7", "pump vibration", HIGH,
                "CREATED", new BigDecimal("999.99"), "secret-token");
        var node = mapper.valueToTree(DtoFixtures.toResponse(domain));
        assertEquals(Set.of("id", "assetId", "description", "priority", "status"),
                Set.copyOf(node.propertyNames()));
        assertFalse(node.has("internalCost"));
        assertFalse(node.has("assigneeToken"));
    }

    @Test
    void jsonRequestCreates201JsonResponse() throws Exception {
        var result = mvc.perform(post("/work-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON)
                        .content("""
                                {"assetId":"ASSET-7","description":"pump vibration","priority":"HIGH"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andReturn();
        var response = mapper.readTree(result.getResponse().getContentAsString());
        assertEquals(42, response.get("id").asInt());
        assertEquals("CREATED", response.get("status").asText());
        assertEquals(1, useCase.callCount());
    }

    @Test
    void textPlainRequestReturns415BeforeUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.TEXT_PLAIN).content("not-json"))
                .andExpect(status().isUnsupportedMediaType());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void xmlOnlyAcceptReturns406BeforeUseCase() throws Exception {
        mvc.perform(post("/work-orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_XML)
                        .content("{" + "\"assetId\":\"A\",\"description\":\"D\",\"priority\":\"HIGH\"}"))
                .andExpect(status().isNotAcceptable());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void malformedJsonReturns400BeforeUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":"))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void unknownJsonFieldReturns400UnderStrictInputPolicy() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"assetId":"A","description":"D","priority":"HIGH","descriptin":"typo"}
                                """))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void invalidEnumReturns400BeforeUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{" + "\"assetId\":\"A\",\"description\":\"D\",\"priority\":\"URGENT\"}"))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }
}
