package academy.aop;

import java.lang.annotation.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import org.aopalliance.intercept.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.aop.support.DefaultPointcutAdvisor;
import org.springframework.aop.support.annotation.AnnotationMatchingPointcut;

/** Creates real JDK/CGLIB proxies so proxy reachability can be observed without a web context. */
public final class ProxyBoundaryLab {
    private ProxyBoundaryLab() {}
    @Retention(RetentionPolicy.RUNTIME) @Target(ElementType.METHOD) public @interface TimedOperation {}
    public interface Operations {@TimedOperation Object timed(Object value);String plain();@TimedOperation void fail(RuntimeException failure);@TimedOperation String outer();@TimedOperation String inner();}
    public static final class InterfaceTarget implements Operations {public Object timed(Object v){return v;}public String plain(){return "plain";}public void fail(RuntimeException e){throw e;}public String outer(){return inner();}public String inner(){return "inner";}}
    public static class ClassTarget {
        @TimedOperation public String normal(){return "normal";}
        @TimedOperation public final String finalCall(){return "final";}
        @TimedOperation public String outerToPrivate(){return privateStep();}
        @TimedOperation private String privateStep(){return "private";}
    }
    public static final class TimingAdvice implements MethodInterceptor {
        private final AtomicLong ticks=new AtomicLong();private final List<String> events=new ArrayList<>();
        public Object invoke(MethodInvocation call)throws Throwable{long start=ticks.getAndAdd(7);String outcome="ok";try{return call.proceed();}catch(Throwable e){outcome="error";throw e;}finally{events.add(call.getMethod().getName()+":"+outcome+":"+(ticks.getAndAdd(7)-start));}}
        public List<String> events(){return List.copyOf(events);}
    }
    public static JdkFixture jdk(){var target=new InterfaceTarget();var advice=new TimingAdvice();var factory=base(target,advice);factory.setInterfaces(Operations.class);return new JdkFixture((Operations)factory.getProxy(),target,advice);}
    public static ClassFixture cglib(){var target=new ClassTarget();var advice=new TimingAdvice();var factory=base(target,advice);factory.setProxyTargetClass(true);return new ClassFixture((ClassTarget)factory.getProxy(),target,advice);}
    private static ProxyFactory base(Object target,TimingAdvice advice){var factory=new ProxyFactory(target);factory.addAdvisor(new DefaultPointcutAdvisor(AnnotationMatchingPointcut.forMethodAnnotation(TimedOperation.class),advice));return factory;}
    public record JdkFixture(Operations proxy,InterfaceTarget target,TimingAdvice advice){} public record ClassFixture(ClassTarget proxy,ClassTarget target,TimingAdvice advice){}
}
