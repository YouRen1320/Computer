package academy.validation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@ChronologicalDeadline
public record CreateWorkOrderRequest(
        @NotBlank String assetId,
        @NotBlank @Size(max = 500) String description,
        @NotNull Priority priority,
        @NotNull Long createdAt,
        @NotNull Long dueAt) {

    public enum Priority { LOW, HIGH }
}
