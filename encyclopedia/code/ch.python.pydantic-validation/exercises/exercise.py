"""Editable Pydantic boundary-contract exercise."""

from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator


class WorkOrderContract(BaseModel):
    # TODO：启用 strict，并拒绝额外字段。
    model_config = ConfigDict()

    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
        gt=0,
    )
    priority: int = Field(ge=1, le=5)
    escalation_reason: str | None = None

    @model_validator(mode="after")
    def urgent_requires_reason(self) -> Self:
        # TODO：priority == 5 且理由为空时抛出 ValueError。
        return self
