package academy.aop;

import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import static org.assertj.core.api.Assertions.*;

class TimingProxyExampleTest {
    @Test void proxyAndTargetAreDifferentObjects(){var f=TimingProxyExample.create();assertThat(f.proxy()).isNotSameAs(f.target());}
    @Test void interfaceConfigurationCreatesJdkProxy(){assertThat(AopUtils.isJdkDynamicProxy(TimingProxyExample.create().proxy())).isTrue();}
    @Test void matchedExternalCallRecordsExactlyOnce(){var f=TimingProxyExample.create();f.proxy().timed("x");assertThat(f.advice().events()).containsExactly("timed:success:5");}
    @Test void unmatchedCallRecordsNothing(){var f=TimingProxyExample.create();assertThat(f.proxy().plain()).isEqualTo("plain");assertThat(f.advice().events()).isEmpty();}
    @Test void advicePreservesReturnIdentity(){var f=TimingProxyExample.create();var marker=new Object();assertThat(f.proxy().timed(marker)).isSameAs(marker);}
    @Test void advicePreservesExceptionIdentity(){var f=TimingProxyExample.create();var failure=new IllegalStateException("boom");assertThatThrownBy(()->f.proxy().fail(failure)).isSameAs(failure);assertThat(f.advice().events()).containsExactly("fail:failure:5");}
    @Test void selfInvocationDoesNotAdviseInnerAgain(){var f=TimingProxyExample.create();assertThat(f.proxy().outer()).isEqualTo("inner");assertThat(f.advice().events()).containsExactly("outer:success:5");}
    @Test void externalInnerCallIsAdvised(){var f=TimingProxyExample.create();assertThat(f.proxy().inner()).isEqualTo("inner");assertThat(f.advice().events()).containsExactly("inner:success:5");}
    @Test void directTargetCallBypassesProxy(){var f=TimingProxyExample.create();f.target().timed("x");assertThat(f.advice().events()).isEmpty();}
}
