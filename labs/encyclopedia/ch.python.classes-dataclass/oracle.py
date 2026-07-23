from dataclasses import dataclass, field


class BadQueue:
    items: list[str] = []


bad_left = BadQueue()
bad_right = BadQueue()
bad_left.items.append("WO-1")
assert bad_right.items == ["WO-1"]
assert bad_left.items is bad_right.items


@dataclass
class GoodQueue:
    items: list[str] = field(default_factory=list)


good_left = GoodQueue()
good_right = GoodQueue()
good_left.items.append("WO-2")
assert good_right.items == []
assert good_left.items is not good_right.items


@dataclass(frozen=True)
class ShallowFrozen:
    tags: list[str] = field(default_factory=list)


shallow = ShallowFrozen()
shallow.tags.append("urgent")
assert shallow.tags == ["urgent"], "frozen is intentionally shown as shallow"


@dataclass(frozen=True)
class DeepValue:
    tags: tuple[str, ...] = ()


deep = DeepValue(("urgent",))
assert deep.tags + ("safety",) == ("urgent", "safety")
assert deep.tags == ("urgent",), "tuple operation creates a new value"


@dataclass
class DefaultEntity:
    entity_id: str
    display_name: str


assert DefaultEntity("T-1", "Li") != DefaultEntity("T-1", "Lee")


@dataclass(eq=False)
class IdEntity:
    entity_id: str
    display_name: str

    def __eq__(self, other: object) -> bool:
        return isinstance(other, IdEntity) and self.entity_id == other.entity_id


assert IdEntity("T-1", "Li") == IdEntity("T-1", "Lee")
print("PASS classes/dataclass lab: three traps reproduced and repaired")
