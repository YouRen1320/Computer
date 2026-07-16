package academy.aop;

import java.lang.annotation.*;
import org.aopalliance.intercept.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.aop.support.DefaultPointcutAdvisor;
import org.springframework.aop.support.annotation.AnnotationMatchingPointcut;

/** Starter defect: the timing advice turns a target failure into a successful fallback. */
public final class TransparentTiming {
    @Retention(RetentionPolicy.RUNTIME) @Target(ElementType.METHOD) public @interface Timed {}
    public interface Operations {@Timed String success();@Timed String fail(RuntimeException failure);}
    public static final class TargetOperations implements Operations {public String success(){return "ok";}public String fail(RuntimeException failure){throw failure;}}
    public static final class TimingAdvice implements MethodInterceptor {private int recordings;public Object invoke(MethodInvocation call)throws Throwable{try{return call.proceed();}catch(RuntimeException swallowed){return "fallback";}finally{recordings++;}}public int recordings(){return recordings;}}
    public static Fixture create(){var advice=new TimingAdvice();var factory=new ProxyFactory(new TargetOperations());factory.setInterfaces(Operations.class);factory.addAdvisor(new DefaultPointcutAdvisor(AnnotationMatchingPointcut.forMethodAnnotation(Timed.class),advice));return new Fixture((Operations)factory.getProxy(),advice);}
    public record Fixture(Operations proxy,TimingAdvice advice){}
}
