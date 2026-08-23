package academy.boot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import academy.app.ProfileAdapterConfiguration;
import academy.app.StorageAdapter;
import academy.audit.AuditLibraryMarker;
import academy.audit.AuditSink;
import academy.boot.autoconfigure.AuditAutoConfiguration;
import academy.boot.autoconfigure.ManagedAuditSink;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.condition.ConditionEvaluationReport;
import org.springframework.boot.test.context.FilteredClassLoader;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

class BootAutoConfigurationLabTest {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(AuditAutoConfiguration.class));

    @Test
    void importsFileContainsExactlyThePublishedCandidate() throws IOException {
        try (var stream = getClass().getClassLoader().getResourceAsStream(
                "META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports")) {
            assertNotNull(stream);
            assertEquals(AuditAutoConfiguration.class.getName(),
                    new String(stream.readAllBytes(), StandardCharsets.UTF_8).trim());
        }
    }

    @Test
    void classConditionMatchesWhenLibraryMarkerExists() {
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .run(context -> assertEquals(1, context.getBeansOfType(AuditSink.class).size()));
    }

    @Test
    void classConditionBacksOffWhenLibraryMarkerIsFiltered() {
        runner.withClassLoader(new FilteredClassLoader(AuditLibraryMarker.class))
                .withPropertyValues("factorycare.audit.enabled=true")
                .run(context -> assertTrue(context.getBeansOfType(AuditSink.class).isEmpty()));
    }

    @Test
    void missingAndFalsePropertiesBothKeepFeatureDisabled() {
        runner.run(context -> assertTrue(context.getBeansOfType(AuditSink.class).isEmpty()));
        runner.withPropertyValues("factorycare.audit.enabled=false")
                .run(context -> assertTrue(context.getBeansOfType(AuditSink.class).isEmpty()));
    }

    @Test
    void truePropertyCreatesOnlyTheManagedDefault() {
        runner.withPropertyValues("factorycare.audit.enabled=true").run(context -> {
            assertEquals(1, context.getBeansOfType(AuditSink.class).size());
            assertEquals(1, context.getBeansOfType(ManagedAuditSink.class).size());
        });
    }

    @Test
    void userBeanBacksOffTheDefaultWithoutEnablingGlobalOverrides() {
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .withUserConfiguration(UserAuditConfiguration.class)
                .run(context -> {
                    assertEquals(1, context.getBeansOfType(AuditSink.class).size());
                    assertEquals("database", context.getBean(AuditSink.class).destination());
                    assertTrue(context.getBeansOfType(ManagedAuditSink.class).isEmpty());
                });
    }

    @Test
    void reportDistinguishesNegativeAndPositivePropertyOutcomes() {
        runner.run(context -> assertFalse(methodOutcome(context).isFullMatch()));
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .run(context -> assertTrue(methodOutcome(context).isFullMatch()));
    }

    @Test
    void defaultProfileSelectsProductionAdapterOnly() {
        new ApplicationContextRunner().withUserConfiguration(ProfileAdapterConfiguration.class)
                .run(context -> {
                    assertEquals(1, context.getBeansOfType(StorageAdapter.class).size());
                    assertEquals("production", context.getBean(StorageAdapter.class).name());
                });
    }

    @Test
    void devProfileSelectsSandboxAdapterOnly() {
        new ApplicationContextRunner().withUserConfiguration(ProfileAdapterConfiguration.class)
                .withInitializer(context -> context.getEnvironment().setActiveProfiles("dev"))
                .run(context -> {
                    assertEquals(1, context.getBeansOfType(StorageAdapter.class).size());
                    assertEquals("sandbox", context.getBean(StorageAdapter.class).name());
                });
    }

    @Test
    void constructorCycleFailsContextStartup() {
        new ApplicationContextRunner().withUserConfiguration(CircularConfiguration.class)
                .run(context -> assertNotNull(context.getStartupFailure()));
    }

    @Test
    void managedResourceClosesWhenRunnerClosesContext() {
        ManagedAuditSink.resetCloseCount();
        runner.withPropertyValues("factorycare.audit.enabled=true")
                .run(context -> assertEquals(0, ManagedAuditSink.closeCount()));
        assertEquals(1, ManagedAuditSink.closeCount());
    }

    private static ConditionEvaluationReport.ConditionAndOutcomes methodOutcome(
            org.springframework.context.ConfigurableApplicationContext context) {
        return ConditionEvaluationReport.get(context.getBeanFactory())
                .getConditionAndOutcomesBySource().entrySet().stream()
                .filter(entry -> entry.getKey().contains(AuditAutoConfiguration.class.getName()))
                .filter(entry -> entry.getKey().endsWith("#auditSink"))
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

    @Configuration(proxyBeanMethods = false)
    static class CircularConfiguration {
        @Bean
        Left left(Right right) {
            return new Left();
        }

        @Bean
        Right right(Left left) {
            return new Right();
        }
    }

    static final class Left {}
    static final class Right {}
}
