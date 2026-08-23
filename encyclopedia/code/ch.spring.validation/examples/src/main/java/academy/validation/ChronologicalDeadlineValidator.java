package academy.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

public final class ChronologicalDeadlineValidator
        implements ConstraintValidator<ChronologicalDeadline, CreateWorkOrderRequest> {

    @Override
    public boolean isValid(CreateWorkOrderRequest request, ConstraintValidatorContext context) {
        if (request == null || request.createdAt() == null || request.dueAt() == null) {
            return true;
        }
        if (request.dueAt() > request.createdAt()) {
            return true;
        }
        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate("dueAt must be later than createdAt")
                .addPropertyNode("dueAt")
                .addConstraintViolation();
        return false;
    }
}
