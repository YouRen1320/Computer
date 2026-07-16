package academy.beans;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.DisposableBean;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.beans.factory.config.ConfigurableBeanFactory;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Scope;
import org.springframework.context.annotation.ScopedProxyMode;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.context.request.RequestScope;
import org.springframework.web.context.request.SessionScope;

public final class BeanLifecycleFixtures {
    private static final AtomicInteger IDS = new AtomicInteger();
    private static final AtomicInteger PROTOTYPE_DESTROYED = new AtomicInteger();
    private static final AtomicInteger REQUEST_DESTROYED = new AtomicInteger();

    private BeanLifecycleFixtures() {
    }

    public static void resetCounters() {
        IDS.set(0);
        PROTOTYPE_DESTROYED.set(0);
        REQUEST_DESTROYED.set(0);
    }

    public static int prototypeDestroyed() {
        return PROTOTYPE_DESTROYED.get();
    }

    public static int requestDestroyed() {
        return REQUEST_DESTROYED.get();
    }

    public static AnnotationConfigApplicationContext newScopedContext() {
        var context = new AnnotationConfigApplicationContext();
        context.getBeanFactory().registerScope(
                WebApplicationContext.SCOPE_REQUEST, new RequestScope());
        context.getBeanFactory().registerScope(
                WebApplicationContext.SCOPE_SESSION, new SessionScope());
        context.register(ScopeConfig.class);
        context.refresh();
        return context;
    }

    public static final class LifecycleLog {
        private final List<String> events = new CopyOnWriteArrayList<>();

        public void add(String event) {
            events.add(event);
        }

        public List<String> snapshot() {
            return List.copyOf(events);
        }
    }

    public record Dependency(String name) {
    }

    public static final class ObservedBean implements InitializingBean, DisposableBean {
        private final LifecycleLog log;
        private Dependency dependency;

        public ObservedBean(LifecycleLog log) {
            this.log = log;
            log.add("observed:constructed");
        }

        @Autowired
        public void setDependency(Dependency dependency) {
            this.dependency = dependency;
            log.add("observed:dependency-filled");
        }

        @Override
        public void afterPropertiesSet() {
            if (dependency == null) {
                throw new IllegalStateException("EXPECTED_DEPENDENCY_BEFORE_INIT");
            }
            log.add("observed:after-properties-set");
        }

        public void customInit() {
            log.add("observed:custom-init");
        }

        public String use() {
            log.add("observed:used");
            return dependency.name();
        }

        @Override
        public void destroy() {
            log.add("observed:destroy");
        }

        public void customDestroy() {
            log.add("observed:custom-destroy");
        }
    }

    public static final class TracePostProcessor implements BeanPostProcessor {
        private final LifecycleLog log;

        public TracePostProcessor(LifecycleLog log) {
            this.log = log;
        }

        @Override
        public Object postProcessBeforeInitialization(Object bean, String beanName)
                throws BeansException {
            if ("observedBean".equals(beanName)) {
                log.add("observed:before-init");
            }
            return bean;
        }

        @Override
        public Object postProcessAfterInitialization(Object bean, String beanName)
                throws BeansException {
            if ("observedBean".equals(beanName)) {
                log.add("observed:after-init");
            }
            return bean;
        }
    }

    @Configuration(proxyBeanMethods = false)
    public static class LifecycleConfig {
        @Bean
        LifecycleLog lifecycleLog() {
            return new LifecycleLog();
        }

        @Bean
        static TracePostProcessor tracePostProcessor(LifecycleLog log) {
            return new TracePostProcessor(log);
        }

        @Bean
        Dependency dependency() {
            return new Dependency("equipment-catalog");
        }

        @Bean(initMethod = "customInit", destroyMethod = "customDestroy")
        ObservedBean observedBean(LifecycleLog log) {
            return new ObservedBean(log);
        }
    }

    public static final class SingletonProbe {
        private final int id = IDS.incrementAndGet();

        public int id() {
            return id;
        }
    }

    public static final class PrototypeResource implements DisposableBean {
        private final int id = IDS.incrementAndGet();
        private final AtomicBoolean released = new AtomicBoolean();

        public int id() {
            return id;
        }

        public boolean released() {
            return released.get();
        }

        public void release() {
            if (released.compareAndSet(false, true)) {
                PROTOTYPE_DESTROYED.incrementAndGet();
            }
        }

        @Override
        public void destroy() {
            release();
        }
    }

    public static final class CapturingIssuer {
        private final PrototypeResource captured;

        public CapturingIssuer(PrototypeResource captured) {
            this.captured = captured;
        }

        public int issue() {
            return captured.id();
        }
    }

    public static final class ProviderIssuer {
        private final ObjectProvider<PrototypeResource> resources;

        public ProviderIssuer(ObjectProvider<PrototypeResource> resources) {
            this.resources = resources;
        }

        public int issue() {
            return resources.getObject().id();
        }
    }

    public static final class RequestProbe implements DisposableBean {
        private final int id = IDS.incrementAndGet();

        public int id() {
            return id;
        }

        @Override
        public void destroy() {
            REQUEST_DESTROYED.incrementAndGet();
        }
    }

    public static final class SessionProbe {
        private final int id = IDS.incrementAndGet();

        public int id() {
            return id;
        }
    }

    public static final class UnsafeCounter {
        private final CyclicBarrier collision = new CyclicBarrier(2);
        private int value;

        public int incrementWithForcedCollision() {
            int observed = value;
            try {
                collision.await(3, TimeUnit.SECONDS);
            } catch (Exception failure) {
                throw new IllegalStateException("EXPECTED_TWO_CALLERS", failure);
            }
            value = observed + 1;
            return value;
        }

        public int value() {
            return value;
        }
    }

    @Configuration(proxyBeanMethods = false)
    public static class ScopeConfig {
        @Bean
        SingletonProbe singletonProbe() {
            return new SingletonProbe();
        }

        @Bean
        @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
        PrototypeResource prototypeResource() {
            return new PrototypeResource();
        }

        @Bean
        CapturingIssuer capturingIssuer(PrototypeResource resource) {
            return new CapturingIssuer(resource);
        }

        @Bean
        ProviderIssuer providerIssuer(ObjectProvider<PrototypeResource> resources) {
            return new ProviderIssuer(resources);
        }

        @Bean
        UnsafeCounter unsafeCounter() {
            return new UnsafeCounter();
        }

        @Bean
        @Scope(value = WebApplicationContext.SCOPE_REQUEST, proxyMode = ScopedProxyMode.NO)
        RequestProbe requestProbe() {
            return new RequestProbe();
        }

        @Bean
        @Scope(value = WebApplicationContext.SCOPE_SESSION, proxyMode = ScopedProxyMode.NO)
        SessionProbe sessionProbe() {
            return new SessionProbe();
        }
    }
}
