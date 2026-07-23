from dataclasses import dataclass


@dataclass(frozen=True, slots=True, kw_only=True)
class PrioritySuggestion:
    order_id: str
    level: int

    def __post_init__(self) -> None:
        # TODO: 校验 order_id 与 level，不允许半合法对象。
        pass
