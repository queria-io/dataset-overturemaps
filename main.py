"""Overture Maps データパイプライン。

1. places: 最新リリースから日本の POI を取り出す
2. dbt: dbt ビルド
"""

import logging

from dbt.cli.main import dbtRunner

from pipelines.places import download_places

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("pipelines")


def dbt_build():
    dbt = dbtRunner()
    for command in (["deps"], ["build"], ["docs", "generate"]):
        result = dbt.invoke(command)
        if not result.success:
            raise SystemExit(f"dbt {' '.join(command)} failed")


def main():
    logger.info("1/2: places (Overture Maps 日本の POI)")
    download_places()

    logger.info("2/2: dbt build")
    dbt_build()


if __name__ == "__main__":
    main()
