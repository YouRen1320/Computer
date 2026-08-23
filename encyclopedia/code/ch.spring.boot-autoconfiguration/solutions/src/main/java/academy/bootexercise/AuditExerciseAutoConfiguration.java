package academy.bootexercise;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
public class AuditExerciseAutoConfiguration {

    @Bean
    @ConditionalOnBooleanProperty(prefix = "factorycare.audit", name = "enabled")
    @ConditionalOnMissingBean(AuditSink.class)
    ManagedAuditSink auditSink() {
        return new ManagedAuditSink();
    }
}
