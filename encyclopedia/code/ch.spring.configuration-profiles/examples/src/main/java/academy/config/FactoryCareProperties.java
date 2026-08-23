package academy.config;

import java.time.Duration;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "factorycare", ignoreUnknownFields = false)
public record FactoryCareProperties(
        @NotBlank String apiBaseUrl,
        @Valid @NotNull Retry retry,
        @NotNull Duration timeout,
        @NotBlank String apiKey) {

    public record Retry(@Min(1) @Max(10) int maxAttempts) {}

    public String safeSummary() {
        return "apiBaseUrl=%s,maxAttempts=%d,timeout=%s,apiKey=[REDACTED]"
                .formatted(apiBaseUrl, retry.maxAttempts(), timeout);
    }
}
