package academy.actuator;

import io.micrometer.core.instrument.MeterRegistry;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.junit.jupiter.api.*;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import tools.jackson.databind.json.JsonMapper;
import static org.assertj.core.api.Assertions.*;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class ActuatorHttpLabTest {
    private static final JsonMapper JSON=JsonMapper.builder().build(); private static ConfigurableApplicationContext context; private static HttpClient http; private static String root; private static ActuatorLabApplication.DependencySwitch dependency; private static ActuatorLabApplication.WorkOrderMetrics metrics; private static MeterRegistry registry;
    @BeforeAll static void start(){context=SpringApplication.run(ActuatorLabApplication.class,"--server.port=0","--spring.main.banner-mode=off","--logging.level.root=ERROR");int port=context.getEnvironment().getRequiredProperty("local.server.port",Integer.class);root="http://127.0.0.1:"+port;http=HttpClient.newHttpClient();dependency=context.getBean(ActuatorLabApplication.DependencySwitch.class);metrics=context.getBean(ActuatorLabApplication.WorkOrderMetrics.class);registry=context.getBean(MeterRegistry.class);}
    @AfterAll static void stop(){if(context!=null)context.close();}
    @BeforeEach void recover(){dependency.set(true);}

    @Test @Order(1) void anonymousHealthIsMinimal() throws Exception {var r=get("/actuator/health",false);assertThat(r.statusCode()).isEqualTo(200);var json=JSON.readTree(r.body());assertThat(json.get("status").asString()).isEqualTo("UP");assertThat(json.has("components")).isFalse();}
    @Test @Order(2) void livenessIsAvailableAnonymously() throws Exception {assertThat(get("/actuator/health/liveness",false).statusCode()).isEqualTo(200);}
    @Test @Order(3) void readinessStartsUp() throws Exception {var r=get("/actuator/health/readiness",false);assertThat(r.statusCode()).isEqualTo(200);assertThat(JSON.readTree(r.body()).get("status").asString()).isEqualTo("UP");}
    @Test @Order(4) void databaseOutageOnlyRemovesReadiness() throws Exception {dependency.set(false);var ready=get("/actuator/health/readiness",false);var live=get("/actuator/health/liveness",false);assertThat(ready.statusCode()).isEqualTo(503);assertThat(JSON.readTree(ready.body()).get("status").asString()).isEqualTo("DOWN");assertThat(live.statusCode()).isEqualTo(200);assertThat(JSON.readTree(live.body()).get("status").asString()).isEqualTo("UP");}
    @Test @Order(5) void readinessRecovers() throws Exception {dependency.set(false);assertThat(get("/actuator/health/readiness",false).statusCode()).isEqualTo(503);dependency.set(true);assertThat(get("/actuator/health/readiness",false).statusCode()).isEqualTo(200);}
    @Test @Order(6) void metricsRejectsAnonymousCaller() throws Exception {assertThat(get("/actuator/metrics",false).statusCode()).isEqualTo(401);}
    @Test @Order(7) void authenticatedOperatorCanListMetrics() throws Exception {metrics.created("P1","wo-1");var r=get("/actuator/metrics",true);assertThat(r.statusCode()).isEqualTo(200);assertThat(r.body()).contains("factorycare.workorders.created");}
    @Test @Order(8) void metricEndpointShowsBoundedTagsAndCount() throws Exception {double before=registry.get("factorycare.workorders.created").tag("priority","P1").counter().count();metrics.created("P1","wo-2");var r=get("/actuator/metrics/factorycare.workorders.created?tag=priority:P1",true);assertThat(r.statusCode()).isEqualTo(200);assertThat(r.body()).contains("COUNT","result","success");assertThat(registry.get("factorycare.workorders.created").tag("priority","P1").counter().count()).isEqualTo(before+1);}
    @Test @Order(9) void envRemainsUnexposedEvenToAuthenticatedUser() throws Exception {assertThat(get("/actuator/env",true).statusCode()).isEqualTo(404);}
    @Test @Order(10) void workOrderIdsDoNotIncreaseSeriesCardinality() {for(int i=0;i<1000;i++)metrics.created("P2","wo-"+i);assertThat(registry.find("factorycare.workorders.created").meters()).hasSizeLessThanOrEqualTo(4);assertThat(registry.find("factorycare.workorders.created").meters()).allSatisfy(meter->assertThat(meter.getId().getTag("workOrderId")).isNull());}

    private static HttpResponse<String> get(String path,boolean authenticated)throws Exception{var request=HttpRequest.newBuilder(URI.create(root+path)).GET();if(authenticated)request.header("Authorization","Basic "+Base64.getEncoder().encodeToString("ops:actuator-lab-only".getBytes(StandardCharsets.UTF_8)));return http.send(request.build(),HttpResponse.BodyHandlers.ofString());}
}
