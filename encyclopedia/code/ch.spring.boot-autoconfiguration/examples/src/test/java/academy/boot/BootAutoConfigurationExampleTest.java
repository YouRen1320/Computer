package academy.boot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import academy.app.FactoryCareBootApplication;
import academy.app.ProfileAdapterConfiguration;
import academy.app.StorageAdapter;
import academy.audit.AuditSink;
import academy.boot.autoconfigure.AuditAutoConfiguration;
import academy.boot.autoconfigure.ManagedAuditSink;
import org.junit.jupiter.api.Test;
import org.springframework.boot.Banner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.condition.ConditionEvaluationReport;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

class BootAutoConfigurationExampleTest {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(AuditAutoConfiguration.class));

    @Test
    void importsResourcePublishesAutoConfigurationCandidate() throws IOException {
        try (var stream = getClass().getClassLoader().getResourceAsStream(
                "META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports")) {
            assertNotNull(stream);
            assertEquals(AuditAutoConfiguration.class.getName(),
                    new String(stream.readAllBytes(), StandardCharsets.UTF_8).trim());
        }
    }

    @Test
    void missingPropertyKeepsDefaultDisabledAndReportExplainsIt() {
        runner.run(context -> {
            assertTrue(context.getBeansOfType(AuditSink.class).isEmpty());
            assertFalse(methodOutcome(context, "#auditSink").isFullMatch());
        });
    }

    @Test
    void falsePropertyKeepsDefaultDisabled() {
        runner.withPropertyValues("factorycare.audit.enabled=false")
                .run(context -> assertTrue(context.getBeansOfType(AuditSink.class).isEmpty()));
    }

    @Test
    void truePropertyCreatesExactlyOneManagedDefault() {
        runner.withPropertyValues("factorycare.audit.enabled=true").run(context -> {
            assertEquals(1, context.getBeansOfType(AuditSink.class).size());
            assertEquals("console", context.getBean(AuditSink.class).destination());
            assertTrue(methodOutcome(context, "#auditSink").isFullMatch());
        });
    }

    @Test
    void userBeanMakesDefaultBackOff() {
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .withUserConfiguration(UserAuditConfiguration.class)
                .run(context -> {
                    assertEquals(1, context.getBeansOfType(AuditSink.class).size());
                    assertEquals("database", context.getBean(AuditSink.class).destination());
                    assertTrue(context.getBeansOfType(ManagedAuditSink.class).isEmpty());
                });
    }

    @Test
    void managedDefaultIsClosedWithContext() {
        ManagedAuditSink.resetCloseCount();
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .run(context -> assertEquals(0, ManagedAuditSink.closeCount()));
        assertEquals(1, ManagedAuditSink.closeCount());
    }

    @Test
    void defaultAndDevProfilesSelectOnePredictableAdapter() {
        var profiles = new ApplicationContextRunner().withUserConfiguration(ProfileAdapterConfiguration.class);
        profiles.run(context -> assertEquals("production", context.getBean(StorageAdapter.class).name()));
        profiles.withInitializer(context -> context.getEnvironment().setActiveProfiles("dev"))
                .run(context -> assertEquals("sandbox", context.getBean(StorageAdapter.class).name()));
    }

    @Test
    void springApplicationDiscoversImportsAndStartsNonWebContext() {
        SpringApplication application = new SpringApplication(FactoryCareBootApplication.class);
        application.setWebApplicationType(WebApplicationType.NONE);
        application.setBannerMode(Banner.Mode.OFF);
        application.setLogStartupInfo(false);
        try (var context = application.run("--factorycare.audit.enabled=true")) {
            assertEquals("console", context.getBean(AuditSink.class).destination());
            assertEquals("production", context.getBean(StorageAdapter.class).name());
        }
    }

    private static ConditionEvaluationReport.ConditionAndOutcomes methodOutcome(
            org.springframework.context.ConfigurableApplicationContext context, String suffix) {
        return ConditionEvaluationReport.get(context.getBeanFactory())
                .getConditionAndOutcomesBySource().entrySet().stream()
                .filter(entry -> entry.getKey().contains(AuditAutoConfiguration.class.getName()))
                .filter(entry -> entry.getKey().endsWith(suffix))
                .map(java.util.Map.Entry::getValue)
                .findFirst().orElseThrow();
    }

    @Configuration(proxyBeanMethods = false)
    static class UserAuditConfiguration {
        @Bean
        AuditSink auditSink() {
            return () -> "database";
        }
    }
}
