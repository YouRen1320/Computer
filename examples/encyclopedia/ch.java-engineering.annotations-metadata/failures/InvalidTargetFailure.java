import java.lang.annotation.ElementType;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@interface MethodOnly {
}

@MethodOnly
final class InvalidTargetFailure {
}
