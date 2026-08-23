"""Print reproducible interpreter evidence without third-party packages."""

from __future__ import annotations

import json
import platform
import sys


evidence = {
    "implementation": platform.python_implementation(),
    "version": list(sys.version_info[:3]),
    "executable": sys.executable,
    "prefix": sys.prefix,
    "base_prefix": sys.base_prefix,
    "json_module": json.__file__,
}
print(json.dumps(evidence, ensure_ascii=False, sort_keys=True))
