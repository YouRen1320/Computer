from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator


class WorkOrderContract(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
        gt=0,
    )
    priority: int = Field(ge=1, le=5)
    escalation_reason: str | None = None

    @model_validator(mode="after")
    def urgent_requires_reason(self) -> Self:
        if self.priority == 5 and not self.escalation_reason:
            raise ValueError("priority 5 requires escalation_reason")
        return self
