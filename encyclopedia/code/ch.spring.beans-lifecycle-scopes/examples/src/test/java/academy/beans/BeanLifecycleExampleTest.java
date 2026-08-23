package academy.beans;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotSame;
import static org.junit.jupiter.api.Assertions.assertSame;

import academy.beans.BeanLifecycleFixtures.CapturingIssuer;
import academy.beans.BeanLifecycleFixtures.LifecycleLog;
import academy.beans.BeanLifecycleFixtures.ObservedBean;
import academy.beans.BeanLifecycleFixtures.PrototypeResource;
import academy.beans.BeanLifecycleFixtures.ProviderIssuer;
import academy.beans.BeanLifecycleFixtures.RequestProbe;
import academy.beans.BeanLifecycleFixtures.SessionProbe;
import academy.beans.BeanLifecycleFixtures.SingletonProbe;
import java.util.List;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

class BeanLifecycleExampleTest {
    @BeforeEach
    void resetCounters() {
        BeanLifecycleFixtures.resetCounters();
    }

    @Test
    void lifecycleEventsShowFillPostProcessingInitializationAndDestruction() {
        var context = new AnnotationConfigApplicationContext();
        context.register(BeanLifecycleFixtures.LifecycleConfig.class);
        context.refresh();
        LifecycleLog log = context.getBean(LifecycleLog.class);

        assertEquals(List.of(
                "observed:constructed",
                "observed:dependency-filled",
                "observed:before-init",
                "observed:after-properties-set",
                "observed:custom-init",
                "observed:after-init"), log.snapshot());
        assertEquals("equipment-catalog", context.getBean(ObservedBean.class).use());
        context.close();

        assertEquals(List.of(
                "observed:constructed",
                "observed:dependency-filled",
                "observed:before-init",
                "observed:after-properties-set",
                "observed:custom-init",
                "observed:after-init",
                "observed:used",
                "observed:destroy",
                "observed:custom-destroy"), log.snapshot());
    }

    @Test
    void singletonIsReusedWhilePrototypeIsRecreated() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            assertSame(context.getBean(SingletonProbe.class), context.getBean(SingletonProbe.class));
            assertNotSame(context.getBean(PrototypeResource.class), context.getBean(PrototypeResource.class));
        }
    }

    @Test
    void directPrototypeInjectionCapturesOneButProviderGetsFreshInstances() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            CapturingIssuer captured = context.getBean(CapturingIssuer.class);
            ProviderIssuer provider = context.getBean(ProviderIssuer.class);

            assertEquals(captured.issue(), captured.issue());
            int first = provider.issue();
            int second = provider.issue();
            assertNotSame(
                    context.getBean(PrototypeResource.class),
                    context.getBean(PrototypeResource.class));
            org.junit.jupiter.api.Assertions.assertNotEquals(first, second);
        }
    }

    @Test
    void prototypeDestructionBelongsToTheCaller() {
        var context = BeanLifecycleFixtures.newScopedContext();
        PrototypeResource first = context.getBean(PrototypeResource.class);
        PrototypeResource second = context.getBean(PrototypeResource.class);
        context.close();

        assertEquals(0, BeanLifecycleFixtures.prototypeDestroyed());
        first.release();
        second.release();
        assertEquals(2, BeanLifecycleFixtures.prototypeDestroyed());
    }

    @Test
    void requestScopeReusesWithinOneRequestAndChangesForTheNext() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            MockHttpServletRequest firstRequest = new MockHttpServletRequest();
            RequestProbe first = inRequest(firstRequest, () -> {
                RequestProbe one = context.getBean(RequestProbe.class);
                assertSame(one, context.getBean(RequestProbe.class));
                return one;
            });
            assertEquals(1, BeanLifecycleFixtures.requestDestroyed());

            RequestProbe second = inRequest(
                    new MockHttpServletRequest(), () -> context.getBean(RequestProbe.class));
            assertNotSame(first, second);
            assertEquals(2, BeanLifecycleFixtures.requestDestroyed());
        }
    }

    @Test
    void sessionScopeReusesAcrossRequestsForOneSession() {
        try (var context = BeanLifecycleFixtures.newScopedContext()) {
            MockHttpSession shared = new MockHttpSession();
            SessionProbe first = inRequest(requestFor(shared), () -> context.getBean(SessionProbe.class));
            SessionProbe second = inRequest(requestFor(shared), () -> context.getBean(SessionProbe.class));
            SessionProbe other = inRequest(
                    requestFor(new MockHttpSession()), () -> context.getBean(SessionProbe.class));

            assertSame(first, second);
            assertNotSame(first, other);
        }
    }

    private static MockHttpServletRequest requestFor(MockHttpSession session) {
        MockHttpServletRequest request = new MockHttpServletRequest(session.getServletContext());
        request.setSession(session);
        return request;
    }

    private static <T> T inRequest(MockHttpServletRequest request, Supplier<T> action) {
        var attributes = new ServletRequestAttributes(request);
        RequestContextHolder.setRequestAttributes(attributes);
        try {
            return action.get();
        } finally {
            attributes.requestCompleted();
            RequestContextHolder.resetRequestAttributes();
        }
    }
}
