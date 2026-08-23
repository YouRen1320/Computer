package academy.openapi;

import java.net.*;
import java.net.http.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import static org.assertj.core.api.Assertions.*;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class OpenApiRuntimeContractTest {
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static ConfigurableApplicationContext context;
    private static HttpClient http;
    private static String root;
    private static JsonNode spec;

    @BeforeAll static void start() throws Exception {
        context = SpringApplication.run(OpenApiLabApplication.class, "--server.port=0", "--spring.main.banner-mode=off", "--logging.level.root=ERROR");
        int port = context.getEnvironment().getRequiredProperty("local.server.port", Integer.class);
        root = "http://127.0.0.1:" + port; http = HttpClient.newHttpClient(); spec = JSON.readTree(get("/v3/api-docs").body());
    }
    @AfterAll static void stop() { if (context != null) context.close(); }

    @Test @Order(1) void generatedDocumentIsParseableOpenApi() { assertThat(spec.get("openapi").asString()).startsWith("3."); }
    @Test @Order(2) void generatedOperationKeepsStableIdentity() { assertThat(operation().get("operationId").asString()).isEqualTo("getWorkOrder"); }
    @Test @Order(3) void generatedOperationDeclaresSuccessAndProblemStatuses() { assertThat(fieldNames(operation().get("responses"))).containsExactlyInAnyOrder("200","404"); }
    @Test @Order(4) void generatedSuccessSchemaPromisesRequiredFields() { assertThat(required(resolveSchema(operation().get("responses").get("200").get("content").get("application/json").get("schema")))).contains("id","status","version"); }
    @Test @Order(5) void generatedExamplesSatisfyRequiredFields() { var value=operation().get("responses").get("200").get("content").get("application/json").get("examples").get("success").get("value"); assertThat(fieldNames(value)).contains("id","status","version"); }
    @Test @Order(6) void problemMediaTypeIsDeclared() { assertThat(operation().get("responses").get("404").get("content").has("application/problem+json")).isTrue(); }
    @Test @Order(7) void runningSuccessMatchesDeclaredStatusAndFields() throws Exception { var response=get("/api/v1/work-orders/wo-7"); assertThat(response.statusCode()).isEqualTo(200); assertThat(fieldNames(JSON.readTree(response.body()))).contains("id","status","version"); }
    @Test @Order(8) void runningFailureMatchesDeclaredProblem() throws Exception { var response=get("/api/v1/work-orders/missing"); assertThat(response.statusCode()).isEqualTo(404); assertThat(response.headers().firstValue("content-type").orElse("")).startsWith("application/problem+json"); assertThat(fieldNames(JSON.readTree(response.body()))).contains("code","message","traceId"); }
    @Test @Order(9) void generatedCandidateMatchesReadOnlyBaseline() throws Exception { var baseline=JSON.readTree(Objects.requireNonNull(getClass().getResourceAsStream("/openapi-baseline.json"))); assertThat(operation().get("operationId").asString()).isEqualTo(baseline.get("operationId").asString()); assertThat(fieldNames(operation().get("responses"))).containsAll(fieldNames(baseline.get("statuses"))); assertThat(required(resolveSchema(operation().get("responses").get("200").get("content").get("application/json").get("schema")))).containsAll(fieldNames(baseline.get("required"))); }
    @Test @Order(10) void semanticDiffAllowsOptionalButBlocksRequiredDeletion() { var old=Set.of("id","status","version"); assertThat(compatible(old,Set.of("id","status","version"))).isTrue(); assertThat(compatible(old,Set.of("id","status"))).isFalse(); }

    private static HttpResponse<String> get(String path) throws Exception { return http.send(HttpRequest.newBuilder(URI.create(root+path)).GET().build(), HttpResponse.BodyHandlers.ofString()); }
    private static JsonNode operation() { return spec.get("paths").get("/api/v1/work-orders/{id}").get("get"); }
    private static JsonNode resolveSchema(JsonNode schema) { var ref=schema.get("$ref").asString(); return spec.get("components").get("schemas").get(ref.substring(ref.lastIndexOf('/')+1)); }
    private static Set<String> required(JsonNode schema) { return fieldNames(schema.get("required")); }
    private static Set<String> fieldNames(JsonNode node) { var values=new LinkedHashSet<String>(); if (node.isArray()) node.valueStream().forEach(v->values.add(v.asString())); else values.addAll(node.propertyNames()); return values; }
    private static boolean compatible(Set<String> oldRequired, Set<String> candidateRequired) { return candidateRequired.containsAll(oldRequired); }
}
