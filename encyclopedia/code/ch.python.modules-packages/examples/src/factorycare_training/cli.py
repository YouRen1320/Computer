"""薄 CLI：解析不可信字符串，把规则交给领域模块。"""

import argparse

from factorycare_training.priority import normalize_priority


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--priority", required=True, type=int)
    args = parser.parse_args(argv)
    try:
        priority = normalize_priority(args.priority)
    except ValueError as error:
        parser.error(str(error))
    print(priority)
    return 0
