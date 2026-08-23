package academy.beans;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotSame;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import academy.beans.BeanLifecycleFixtures.PrototypeResource;
import academy.beans.BeanLifecycleFixtures.RequestProbe;
import academy.beans.BeanLifecycleFixtures.SessionProbe;
import academy.beans.BeanLifecycleFixtures.SingletonProbe;
import academy.beans.BeanLifecycleFixtures.UnsafeCounter;
import java.util.List;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

class BeanScopesLabTest {
    @BeforeEach
    void reset() {
        BeanLifecycleFixtures.resetCounters();
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void lifecycleLogPlacesDependencyBeforeInitialization() {
        var context = new AnnotationConfigApplicationContext(
                BeanLifecycleFixtures.LifecycleConfig.class);
        var log = context.getBean(BeanLifecycleFixtures.LifecycleLog.class);
        assertEquals(List.of(
                "observed:constructed", "observed:dependency-filled", "observed:before-init",
                "observed:after-properties-set", "observed:custom-init", "observed:after-init"),
                log.snapshot());
        context.close();
        List<String> events = log.snapshot();
        assertEquals(
                List.of("observed:destroy", "observed:custom-destroy"),
                events.subList(events.size() - 2, events.size()));
    }

    @Test
    void singletonIsPerContainerNotGlobalPerClass() {
        try (var first = BeanLifecycleFixtures.newScopedContext();
                var second = BeanLifecycleFixtures.newScopedContext()) {
            assertSame(first.getBean(SingletonProbe.class), first.getBean(SingletonProbe.class));
            assertNotSame(first.getBean(SingletonProbe.class), second.getBean(SingletonProbe.class));
        }
    }

    @Test
    void prototypeIsNewPerLookupButNotDestroyedByContext() {
        var context = BeanLifecycleFixtures.newScopedContext();
        PrototypeResource one = context.getBean(PrototypeResource.class);
        PrototypeResource two = context.getBean(PrototypeResource.class);
        assertNotSame(one, two);
        context.close();
        assertEquals(0, BeanLifecycleFixtures.prototypeDestroyed());
        one.release();
        two.release();
        assertEquals(2, BeanLifecycleFixtures.prototypeDestroyed());
    }

    @Test
    void singletonCapturesDirectPrototypeWhileProviderDoesNot() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            var captured = context.getBean(BeanLifecycleFixtures.CapturingIssuer.class);
            var provider = context.getBean(BeanLifecycleFixtures.ProviderIssuer.class);
            assertEquals(captured.issue(), captured.issue());
            org.junit.jupiter.api.Assertions.assertNotEquals(provider.issue(), provider.issue());
        }
    }

    @Test
    void webScopeMustBeRegistered() {
        try (var context = new AnnotationConfigApplicationContext(
                BeanLifecycleFixtures.ScopeConfig.class)) {
            RuntimeException error = assertThrows(
                    RuntimeException.class, () -> context.getBean(RequestProbe.class));
            assertTrue(error.getMessage().contains("request"));
        }
    }

    @Test
    void registeredRequestScopeStillNeedsAnActiveRequest() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            RuntimeException error = assertThrows(
                    RuntimeException.class, () -> context.getBean(RequestProbe.class));
            assertTrue(error.toString().contains("request"));
        }
    }

    @Test
    void requestAndSessionHaveDifferentIdentityBoundaries() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            MockHttpSession session = new MockHttpSession();
            Snapshot first = lookup(context, requestFor(session));
            Snapshot second = lookup(context, requestFor(session));
            Snapshot third = lookup(context, requestFor(new MockHttpSession()));

            assertNotSame(first.request(), second.request());
            assertSame(first.session(), second.session());
            assertNotSame(first.session(), third.session());
            assertEquals(3, BeanLifecycleFixtures.requestDestroyed());
        }
    }

    @Test
    void singletonScopeDoesNotPreventAForcedLostUpdate() throws Exception {
        try (var context = BeanLifecycleFixtures.newScopedContext();
                var pool = Executors.newFixedThreadPool(2)) {
            UnsafeCounter counter = context.getBean(UnsafeCounter.class);
            var first = pool.submit(counter::incrementWithForcedCollision);
            var second = pool.submit(counter::incrementWithForcedCollision);
            first.get();
            second.get();
            assertEquals(1, counter.value(), "EXPECTED_SINGLETON_RACE");
        }
    }

    private static Snapshot lookup(
            AnnotationConfigApplicationContext context, MockHttpServletRequest request) {
        var attributes = new ServletRequestAttributes(request);
        RequestContextHolder.setRequestAttributes(attributes);
        try {
            return new Snapshot(
                    context.getBean(RequestProbe.class), context.getBean(SessionProbe.class));
        } finally {
            attributes.requestCompleted();
            RequestContextHolder.resetRequestAttributes();
        }
    }

    private static MockHttpServletRequest requestFor(MockHttpSession session) {
        var request = new MockHttpServletRequest(session.getServletContext());
        request.setSession(session);
        return request;
    }

    private record Snapshot(RequestProbe request, SessionProbe session) {
    }
}
