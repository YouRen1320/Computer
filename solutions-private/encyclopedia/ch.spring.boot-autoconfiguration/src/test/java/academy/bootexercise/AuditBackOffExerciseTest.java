package academy.bootexercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.io.IOException;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

class AuditBackOffExerciseTest {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(AuditExerciseAutoConfiguration.class))
            .withPropertyValues("factorycare.audit.enabled=true")
            .withUserConfiguration(UserConfiguration.class);

    @Test
    void importsMetadataIsPublished() throws IOException {
        try (var stream = getClass().getClassLoader().getResourceAsStream(
                "META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports")) {
            assertNotNull(stream);
        }
    }

    @Test
    void userImplementationMustBeTheOnlyAuditSink() {
        runner.run(context -> assertEquals(
                1,
                context.getBeansOfType(AuditSink.class).size(),
                "EXPECTED_SINGLE_AUDIT_SINK: automatic default must back off for the user bean"));
    }

    @Configuration(proxyBeanMethods = false)
    static class UserConfiguration {
        @Bean
        AuditSink databaseAuditSink() {
            return () -> "database";
        }
    }
}
