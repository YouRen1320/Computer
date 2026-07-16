package academy.aop;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class TransparentTimingTest {
    @Test void successReturnAndTimingArePreserved(){var f=TransparentTiming.create();assertThat(f.proxy().success()).isEqualTo("ok");assertThat(f.advice().recordings()).isOne();}
    @Test void failurePropagatesUnchanged(){var f=TransparentTiming.create();var failure=new IllegalStateException("business failure");assertThatThrownBy(()->f.proxy().fail(failure)).as("EXPECTED_EXCEPTION_PROPAGATION").isSameAs(failure);assertThat(f.advice().recordings()).isOne();}
}
