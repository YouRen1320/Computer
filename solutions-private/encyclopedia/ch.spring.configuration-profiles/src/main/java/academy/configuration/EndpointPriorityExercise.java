package academy.configuration;

import java.util.Map;
import java.util.Objects;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.env.PropertySourcesPropertyResolver;
import org.springframework.core.env.SystemEnvironmentPropertySource;

/** Resolves one endpoint with environment values taking precedence over defaults. */
public final class EndpointPriorityExercise {
    static final String ENDPOINT_PROPERTY = "factorycare.api-base-url";
    static final String ENDPOINT_ENVIRONMENT_VARIABLE = "FACTORYCARE_API_BASE_URL";
    static final String DEFAULT_ENDPOINT = "https://default.example.invalid";

    private EndpointPriorityExercise() {
    }

    public static String resolveEndpoint(Map<String, Object> environment) {
        Objects.requireNonNull(environment, "environment");
        MutablePropertySources sources = new MutablePropertySources();

        sources.addFirst(new SystemEnvironmentPropertySource(
                "environment", environment));
        sources.addLast(new MapPropertySource(
                "defaults", Map.of(ENDPOINT_PROPERTY, DEFAULT_ENDPOINT)));

        return new PropertySourcesPropertyResolver(sources)
                .getRequiredProperty(ENDPOINT_PROPERTY);
    }
}
