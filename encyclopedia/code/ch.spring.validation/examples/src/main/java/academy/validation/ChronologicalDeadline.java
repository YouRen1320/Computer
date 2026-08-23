package academy.validation;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

@Documented
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ChronologicalDeadlineValidator.class)
public @interface ChronologicalDeadline {
    String message() default "dueAt must be later than createdAt";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
