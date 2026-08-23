package academy.boot.autoconfigure;

import academy.audit.AuditLibraryMarker;
import academy.audit.AuditSink;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnClass(AuditLibraryMarker.class)
public class AuditAutoConfiguration {

    @Bean
    @ConditionalOnBooleanProperty(prefix = "factorycare.audit", name = "enabled")
    @ConditionalOnMissingBean(AuditSink.class)
    ManagedAuditSink auditSink() {
        return new ManagedAuditSink();
    }
}
