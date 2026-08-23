package academy.configuration;

import java.util.Map;
import java.util.Objects;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.ConfigurationPropertySources;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.env.SystemEnvironmentPropertySource;

/** Resolves one endpoint from explicit property sources without reading the host environment. */
public final class EndpointPriorityExercise {
    static final String ENDPOINT_PROPERTY = "factorycare.api-base-url";
    static final String ENDPOINT_ENVIRONMENT_VARIABLE = "FACTORYCARE_APIBASEURL";
    static final String DEFAULT_ENDPOINT = "https://default.example.invalid";

    private EndpointPriorityExercise() {
    }

    public static String resolveEndpoint(Map<String, Object> environment) {
        Objects.requireNonNull(environment, "environment");
        MutablePropertySources sources = new MutablePropertySources();

        // TODO The higher-priority environment source must be searched before defaults.
        sources.addLast(new MapPropertySource(
                "defaults", Map.of(ENDPOINT_PROPERTY, DEFAULT_ENDPOINT)));
        sources.addLast(new SystemEnvironmentPropertySource(
                StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, environment));

        return new Binder(ConfigurationPropertySources.from(sources))
                .bind(ENDPOINT_PROPERTY, String.class)
                .orElseThrow(() -> new IllegalStateException("endpoint is not configured"));
    }

    static String resolveEnvironmentOnly(Map<String, Object> environment) {
        Objects.requireNonNull(environment, "environment");
        MutablePropertySources sources = new MutablePropertySources();
        sources.addFirst(new SystemEnvironmentPropertySource(
                StandardEnvironment.SYSTEM_ENVIRONMENT_PROPERTY_SOURCE_NAME, environment));
        return new Binder(ConfigurationPropertySources.from(sources))
                .bind(ENDPOINT_PROPERTY, String.class)
                .orElse(null);
    }
}
