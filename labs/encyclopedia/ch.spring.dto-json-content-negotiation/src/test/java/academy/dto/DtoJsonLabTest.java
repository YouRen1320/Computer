package academy.dto;

import static academy.dto.DtoFixtures.Priority.HIGH;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
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

class DtoJsonLabTest {
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
    void requestRoundTripPreservesRecordValues() throws Exception {
        var request = new DtoFixtures.CreateWorkOrderRequest("ASSET-7", "pump vibration", HIGH);
        assertEquals(request, mapper.readValue(mapper.writeValueAsString(request),
                DtoFixtures.CreateWorkOrderRequest.class));
    }

    @Test
    void missingAndExplicitNullBothNeedASeparateValidationPolicy() throws Exception {
        var missing = mapper.readValue("{\"description\":\"D\",\"priority\":\"HIGH\"}",
                DtoFixtures.CreateWorkOrderRequest.class);
        var explicitNull = mapper.readValue(
                "{\"assetId\":null,\"description\":\"D\",\"priority\":\"HIGH\"}",
                DtoFixtures.CreateWorkOrderRequest.class);
        assertNull(missing.assetId());
        assertNull(explicitNull.assetId());
    }

    @Test
    void responseFieldWhitelistExcludesBothInternalFields() {
        var domain = new DtoFixtures.WorkOrder(42, "A", "D", HIGH, "OPEN",
                new BigDecimal("900.00"), "token");
        var node = mapper.valueToTree(DtoFixtures.toResponse(domain));
        assertEquals(Set.of("id", "assetId", "description", "priority", "status"),
                Set.copyOf(node.propertyNames()));
        assertFalse(node.has("internalCost"));
        assertFalse(node.has("assigneeToken"));
    }

    @Test
    void legalJsonAndAcceptProduce201AndJson() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON).content(validJson()))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andReturn();
        var response = mapper.readTree(result.getResponse().getContentAsString());
        assertEquals("ASSET-7", response.get("assetId").asText());
        assertEquals(1, useCase.callCount());
    }

    @Test
    void responseNeverSerializesDomainSecretOrCost() throws Exception {
        var result = mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON).content(validJson()))
                .andExpect(status().isCreated())
                .andReturn();
        var response = mapper.readTree(result.getResponse().getContentAsString());
        assertFalse(response.has("internalCost"));
        assertFalse(response.has("assigneeToken"));
    }

    @Test
    void unsupportedContentTypeReturns415WithoutUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.TEXT_PLAIN).content(validJson()))
                .andExpect(status().isUnsupportedMediaType());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void unsupportedAcceptReturns406WithoutUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_XML).content(validJson()))
                .andExpect(status().isNotAcceptable());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void malformedJsonReturns400WithoutUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void strictMapperRejectsUnknownTypoField() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"assetId":"A","description":"D","priority":"HIGH","descriptin":"x"}
                                """))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void unknownEnumReturns400WithoutUseCase() throws Exception {
        mvc.perform(post("/work-orders").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"assetId\":\"A\",\"description\":\"D\",\"priority\":\"URGENT\"}"))
                .andExpect(status().isBadRequest());
        assertEquals(0, useCase.callCount());
    }

    @Test
    void requestAndResponseWireShapesRemainDifferent() {
        var requestFields = Set.copyOf(mapper.valueToTree(
                new DtoFixtures.CreateWorkOrderRequest("A", "D", HIGH)).propertyNames());
        var responseFields = Set.copyOf(mapper.valueToTree(
                new DtoFixtures.WorkOrderResponse(42, "A", "D", HIGH, "OPEN")).propertyNames());
        assertFalse(requestFields.contains("id"));
        assertFalse(requestFields.contains("status"));
        assertEquals(Set.of("id", "assetId", "description", "priority", "status"), responseFields);
    }

    private static String validJson() {
        return "{\"assetId\":\"ASSET-7\",\"description\":\"pump vibration\",\"priority\":\"HIGH\"}";
    }
}
