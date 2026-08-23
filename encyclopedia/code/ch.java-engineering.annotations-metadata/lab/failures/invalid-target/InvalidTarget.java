import java.lang.annotation.ElementType;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@interface OnlyMethod {
}

final class InvalidTarget {
    @OnlyMethod
    private String deviceId;
}
