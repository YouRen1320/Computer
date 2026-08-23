package academy.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.boot.Banner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.env.SystemEnvironmentPropertySource;

class ConfigurationProfilesLabTest {

    @Test
    void baseFileBindsStringIntegerAndDuration() {
        try (var context = run(Map.of(), "--factorycare.api-key=lab-secret")) {
            var properties = context.getBean(FactoryCareProperties.class);
            assertEquals("https://default.example.invalid", properties.apiBaseUrl());
            assertEquals(2, properties.retry().maxAttempts());
            assertEquals(Duration.ofSeconds(2), properties.timeout());
        }
    }

    @Test
    void profileSpecificFileOverridesOnlyDeclaredKeys() {
        try (var context = run(Map.of(),
                "--spring.profiles.active=dev", "--factorycare.api-key=lab-secret")) {
            var properties = context.getBean(FactoryCareProperties.class);
            assertEquals("https://dev.example.invalid", properties.apiBaseUrl());
            assertEquals(3, properties.retry().maxAttempts());
            assertEquals(Duration.ofSeconds(2), properties.timeout());
        }
    }

    @Test
    void environmentOverridesProfileSpecificFile() {
        try (var context = run(validEnvironment(), "--spring.profiles.active=dev")) {
            assertEquals("https://env.example.invalid",
                    context.getBean(FactoryCareProperties.class).apiBaseUrl());
        }
    }

    @Test
    void commandLineHasHigherPriorityThanEnvironment() {
        try (var context = run(validEnvironment(),
                "--factorycare.api-base-url=https://cli.example.invalid")) {
            assertEquals("https://cli.example.invalid",
                    context.getBean(FactoryCareProperties.class).apiBaseUrl());
        }
    }

    @Test
    void defaultProfileSelectsProductionInfrastructure() {
        try (var context = run(Map.of(), "--factorycare.api-key=lab-secret")) {
            assertEquals("production-adapter",
                    context.getBean(ConfigurationApplication.DeploymentMode.class).adapter());
        }
    }

    @Test
    void devProfileSelectsSandboxInfrastructure() {
        try (var context = run(Map.of(),
                "--spring.profiles.active=dev", "--factorycare.api-key=lab-secret")) {
            assertEquals("sandbox-adapter",
                    context.getBean(ConfigurationApplication.DeploymentMode.class).adapter());
        }
    }

    @Test
    void missingRequiredSecretFailsBeforeContextStarts() {
        assertStartupFailure("apiKey");
    }

    @Test
    void outOfRangeRetryFailsBeforeContextStarts() {
        assertStartupFailure("maxAttempts",
                "--factorycare.api-key=lab-secret", "--factorycare.retry.max-attempts=11");
    }

    @Test
    void unknownConfigurationKeyFailsBecauseBindingIsStrict() {
        assertStartupFailure("max-attempt",
                "--factorycare.api-key=lab-secret", "--factorycare.retry.max-attempt=4");
    }

    @Test
    void diagnosticSummaryRedactsSecret() {
        try (var context = run(Map.of(), "--factorycare.api-key=never-print-me")) {
            String summary = context.getBean(FactoryCareProperties.class).safeSummary();
            assertTrue(summary.contains("[REDACTED]"));
            assertFalse(summary.contains("never-print-me"));
        }
    }

    private static Map<String, Object> validEnvironment() {
        return Map.of(
                "FACTORYCARE_APIBASEURL", "https://env.example.invalid",
                "FACTORYCARE_APIKEY", "environment-secret");
    }

    private static void assertStartupFailure(String expectedMessagePart, String... args) {
        RuntimeException failure = assertThrows(RuntimeException.class, () -> run(Map.of(), args));
        assertTrue(allMessages(failure).contains(expectedMessagePart), allMessages(failure));
    }

    private static String allMessages(Throwable failure) {
        StringBuilder messages = new StringBuilder();
        for (Throwable current = failure; current != null; current = current.getCause()) {
            messages.append(current.getClass().getSimpleName()).append(':')
                    .append(current.getMessage()).append('\n');
        }
        return messages.toString();
    }

    private static ConfigurableApplicationContext run(Map<String, Object> environment, String... args) {
        SpringApplication application = new SpringApplication(ConfigurationApplication.class);
        application.setWebApplicationType(WebApplicationType.NONE);
        application.setBannerMode(Banner.Mode.OFF);
        application.setLogStartupInfo(false);
        if (!environment.isEmpty()) {
            application.addInitializers(context -> context.getEnvironment().getPropertySources().replace(
                    StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME,
                    new SystemEnvironmentPropertySource(
                            StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, environment)));
        }
        return application.run(args);
    }
}
