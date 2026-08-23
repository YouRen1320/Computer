package academy.aop;

import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import static org.assertj.core.api.Assertions.*;

class ProxyBoundaryLabTest {
    @Test void interfaceProxyIsJdk(){assertThat(AopUtils.isJdkDynamicProxy(ProxyBoundaryLab.jdk().proxy())).isTrue();}
    @Test void classProxyIsCglib(){assertThat(AopUtils.isCglibProxy(ProxyBoundaryLab.cglib().proxy())).isTrue();}
    @Test void matchingMethodRecordsExactlyOnce(){var f=ProxyBoundaryLab.jdk();f.proxy().timed("x");assertThat(f.advice().events()).containsExactly("timed:ok:7");}
    @Test void nonMatchingMethodRecordsNothing(){var f=ProxyBoundaryLab.jdk();assertThat(f.proxy().plain()).isEqualTo("plain");assertThat(f.advice().events()).isEmpty();}
    @Test void matchingMethodPreservesReturnIdentity(){var f=ProxyBoundaryLab.jdk();var marker=new Object();assertThat(f.proxy().timed(marker)).isSameAs(marker);}
    @Test void matchingMethodPreservesExceptionIdentity(){var f=ProxyBoundaryLab.jdk();var failure=new IllegalArgumentException("boom");assertThatThrownBy(()->f.proxy().fail(failure)).isSameAs(failure);assertThat(f.advice().events()).containsExactly("fail:error:7");}
    @Test void selfInvocationBypassesInnerAdvice(){var f=ProxyBoundaryLab.jdk();assertThat(f.proxy().outer()).isEqualTo("inner");assertThat(f.advice().events()).containsExactly("outer:ok:7");}
    @Test void externalInnerInvocationIsAdvised(){var f=ProxyBoundaryLab.jdk();f.proxy().inner();assertThat(f.advice().events()).containsExactly("inner:ok:7");}
    @Test void cglibAdvisesOverridablePublicMethod(){var f=ProxyBoundaryLab.cglib();assertThat(f.proxy().normal()).isEqualTo("normal");assertThat(f.advice().events()).containsExactly("normal:ok:7");}
    @Test void cglibCannotAdviseFinalMethod(){var f=ProxyBoundaryLab.cglib();assertThat(f.proxy().finalCall()).isEqualTo("final");assertThat(f.advice().events()).isEmpty();}
    @Test void privateSelfCallIsNotSeparateJoinPoint(){var f=ProxyBoundaryLab.cglib();assertThat(f.proxy().outerToPrivate()).isEqualTo("private");assertThat(f.advice().events()).containsExactly("outerToPrivate:ok:7");}
}
