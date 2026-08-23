package factorycare.challenge;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

// TODO 1..4: 修复目标、保留、重复和类继承策略。
@Retention(RetentionPolicy.SOURCE)
@Target(ElementType.TYPE)
public @interface RequiresRole {
    String value();

    Scope scope() default Scope.TENANT;
}
