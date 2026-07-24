#!/usr/bin/env python3
"""Run the pinned WeasyPrint CLI with deterministic tagged-table identifiers.

WeasyPrint 68.1 uses Python's process-specific ``id(box)`` value for tagged
table-header identifiers. Those values are embedded in otherwise identical
PDFs. This entry point keeps object identity semantics inside one render while
assigning identifiers by deterministic first encounter order.

The patch is deliberately fail-closed on the exact WeasyPrint and pydyf
versions whose internal behavior was reviewed. The resulting PDF remains an
internal review candidate; this patch is not a PDF/UA conformance claim.
"""

from __future__ import annotations

import sys
from typing import Any

import pydyf
import weasyprint
from weasyprint.pdf import tags


EXPECTED_WEASYPRINT = "68.1"
EXPECTED_PYDYF = "0.12.1"


def _fail_if_dependency_drifted() -> None:
    observed = (weasyprint.__version__, pydyf.__version__)
    expected = (EXPECTED_WEASYPRINT, EXPECTED_PYDYF)
    if observed != expected:
        print(
            "deterministic WeasyPrint wrapper dependency drift: "
            f"expected weasyprint={expected[0]} pydyf={expected[1]}, "
            f"observed weasyprint={observed[0]} pydyf={observed[1]}",
            file=sys.stderr,
        )
        raise SystemExit(65)


def _install_stable_table_header_ids() -> None:
    # Keep strong references so a later box cannot reuse an earlier CPython ID.
    # Identity lookup is intentionally linear: the gold sample has hundreds,
    # not millions, of table headers and deterministic behavior matters more.
    observed_objects: list[Any] = []

    def stable_id(value: Any) -> str:
        for index, observed in enumerate(observed_objects, start=1):
            if observed is value:
                return f"factorycare-table-header-{index:06d}"
        observed_objects.append(value)
        return f"factorycare-table-header-{len(observed_objects):06d}"

    # ``tags.py`` resolves ``id`` from its module globals before builtins.
    tags.id = stable_id


def main() -> None:
    _fail_if_dependency_drifted()
    _install_stable_table_header_ids()
    from weasyprint.__main__ import main as weasyprint_main

    weasyprint_main()


if __name__ == "__main__":
    main()
