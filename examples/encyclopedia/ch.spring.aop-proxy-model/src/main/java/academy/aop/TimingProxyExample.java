package academy.aop;

import java.lang.annotation.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;
import org.aopalliance.intercept.MethodInterceptor;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.aop.support.DefaultPointcutAdvisor;
import org.springframework.aop.support.annotation.AnnotationMatchingPointcut;

/** Builds a real JDK Spring AOP proxy with a semantically transparent timing advice. */
public final class TimingProxyExample {
    private TimingProxyExample() {}
    @Retention(RetentionPolicy.RUNTIME) @Target(ElementType.METHOD) public @interface TimedOperation {}
    public interface Operations {
        @TimedOperation Object timed(Object value);
        String plain();
        @TimedOperation void fail(RuntimeException failure);
        @TimedOperation String outer();
        @TimedOperation String inner();
    }
    public static final class TargetOperations implements Operations {
        public Object timed(Object value){return value;} public String plain(){return "plain";} public void fail(RuntimeException failure){throw failure;} public String outer(){return inner();} public String inner(){return "inner";}
    }
    public static final class TimingAdvice implements MethodInterceptor {
        private final LongSupplier clock; private final List<String> events=new ArrayList<>();
        TimingAdvice(LongSupplier clock){this.clock=clock;}
        public Object invoke(org.aopalliance.intercept.MethodInvocation invocation) throws Throwable {long start=clock.getAsLong();String outcome="success";try{return invocation.proceed();}catch(Throwable failure){outcome="failure";throw failure;}finally{events.add(invocation.getMethod().getName()+":"+outcome+":"+(clock.getAsLong()-start));}}
        public List<String> events(){return List.copyOf(events);} public void clear(){events.clear();}
    }
    public static Fixture create(){var ticks=new AtomicLong();var advice=new TimingAdvice(()->ticks.getAndAdd(5));var target=new TargetOperations();var factory=new ProxyFactory(target);factory.setInterfaces(Operations.class);factory.addAdvisor(new DefaultPointcutAdvisor(AnnotationMatchingPointcut.forMethodAnnotation(TimedOperation.class),advice));return new Fixture((Operations)factory.getProxy(),target,advice);}
    public record Fixture(Operations proxy,TargetOperations target,TimingAdvice advice) {}
}
