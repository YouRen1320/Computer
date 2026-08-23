package academy.app;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration(proxyBeanMethods = false)
public class ProfileAdapterConfiguration {

    @Bean
    @Profile("dev")
    StorageAdapter sandboxAdapter() {
        return () -> "sandbox";
    }

    @Bean
    @Profile("!dev")
    StorageAdapter productionAdapter() {
        return () -> "production";
    }
}
