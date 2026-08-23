package academy.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(FactoryCareProperties.class)
public class ConfigurationApplication {

    @Bean
    @Profile("dev")
    DeploymentMode developmentAdapter() {
        return new DeploymentMode("sandbox-adapter");
    }

    @Bean
    @Profile("!dev")
    DeploymentMode standardAdapter() {
        return new DeploymentMode("production-adapter");
    }

    public record DeploymentMode(String adapter) {}
}
