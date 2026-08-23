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

class ConfigurationProfilesExampleTest {

    @Test
    void applicationFileProvidesTypedDefaults() {
        try (var context = run(Map.of(), "--factorycare.api-key=test-only-secret")) {
            var properties = context.getBean(FactoryCareProperties.class);
            assertEquals("https://default.example.invalid", properties.apiBaseUrl());
            assertEquals(2, properties.retry().maxAttempts());
            assertEquals(Duration.ofSeconds(2), properties.timeout());
        }
    }

    @Test
    void activeProfileAddsPredictableOverridesAndInfrastructureSelection() {
        try (var context = run(Map.of(),
                "--spring.profiles.active=dev", "--factorycare.api-key=test-only-secret")) {
            assertEquals("https://dev.example.invalid",
                    context.getBean(FactoryCareProperties.class).apiBaseUrl());
            assertEquals(3, context.getBean(FactoryCareProperties.class).retry().maxAttempts());
            assertEquals("sandbox-adapter",
                    context.getBean(ConfigurationApplication.DeploymentMode.class).adapter());
        }
    }

    @Test
    void environmentOverridesProfileFileUsingCanonicalEnvironmentName() {
        var environment = Map.<String, Object>of(
                "FACTORYCARE_APIBASEURL", "https://env.example.invalid",
                "FACTORYCARE_APIKEY", "environment-secret");
        try (var context = run(environment, "--spring.profiles.active=dev")) {
            assertEquals("https://env.example.invalid",
                    context.getBean(FactoryCareProperties.class).apiBaseUrl());
        }
    }

    @Test
    void commandLineOverridesEnvironment() {
        var environment = Map.<String, Object>of(
                "FACTORYCARE_APIBASEURL", "https://env.example.invalid",
                "FACTORYCARE_APIKEY", "environment-secret");
        try (var context = run(environment,
                "--factorycare.api-base-url=https://cli.example.invalid")) {
            assertEquals("https://cli.example.invalid",
                    context.getBean(FactoryCareProperties.class).apiBaseUrl());
        }
    }

    @Test
    void missingRequiredSecretFailsAtStartup() {
        assertStartupFailure(Map.of(), "apiKey");
    }

    @Test
    void invalidNumericConstraintFailsAtStartup() {
        assertStartupFailure(Map.of(), "maxAttempts",
                "--factorycare.api-key=test-only-secret", "--factorycare.retry.max-attempts=0");
    }

    @Test
    void safeSummaryNeverIncludesSecret() {
        try (var context = run(Map.of(), "--factorycare.api-key=test-only-secret")) {
            String summary = context.getBean(FactoryCareProperties.class).safeSummary();
            assertTrue(summary.contains("apiKey=[REDACTED]"));
            assertFalse(summary.contains("test-only-secret"));
        }
    }

    private static void assertStartupFailure(Map<String, Object> environment,
            String expectedMessagePart, String... args) {
        RuntimeException failure = assertThrows(RuntimeException.class, () -> run(environment, args));
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
